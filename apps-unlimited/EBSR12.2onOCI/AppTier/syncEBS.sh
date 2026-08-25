#!/bin/ksh
################################################################################
# Name: syncEBS.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# Purpose: Use rsync to synchronize the EBS file systems to the standby site
#
#          rsync needs to compare the timestamp on the source file to the
#          timestamp on the target file, to determine wthether or not to copy
#          the file.  To make that faster, here we drill down to lower
#          directory levels and multi-thread the process, making the directory
#          parse complete more quickly.
#
#          We expect the first step of this exercise to be a full rsync copy of
#          the file system to the remote site, which will take signficant time.
#          The goal here is for later runs to go more quickly, using this 
#          script.
#
#          NOTE: Because we expect file synchronization actvities to run on a
#          separate set of VMs, not on the EBS middle tiers, we do not control
#          script execution directly from the stopEBS.sh or startEBS.sh scripts.
#          Instead, those scripts communicate state across servers via hidden
#          files on shared file system.
#          To that end, this script has an added role of making sure a separate
#          script killSync.sh is running in the background.  killSync.sh
#          helps during a switchover from a primary site to a secondary site,
#          making sure any in-process rsync is killed so that one last sweep
#          can be done to make sure all file system changes have been sent
#          from the primary to the secondary, for a clean switchover.
#
#          syncEBS.sh will start killSync.sh under these conditions:
#           -  Replication is enabled.
#           -  The site is in the PRIMARY role.
#           -  syncEBS.sh is not performing a forced sync (f parameter).
#           -  syncEBS.sh is not running in switchover mode (s parameter).
#
#  Usage:  syncEBS.sh <env file controlling this run> [ F|f | S|s ]
#
#  Errors: environment file does not exist, or various parameters within the 
#          env file are nonsense
#
# Revisions:
# Date        What
# 6/1/2025    Start killSync.sh on the server running rsync
# 10/09/2024  Created
################################################################################
# ParseArgs:
# Parse the command line arguments
#
#  Input: command line arguments
# Output: source and target directories set
# Return: exit 1 if arguments are no good
################################################################################
ParseArgs()
{
# Make sure they passed in an env file and it's a file with content
if [ ! -f "${1}" ]; then
   echo "$0: ERROR: ${1} is not a file, does not exist, or is empty."
   Usage
   exit 1
fi

runEnv=${1}

# If there's a second argument, it could be:
# -  F or f, to force rsync even if cannot connect to the database, or
# -  S or s, for running a final sync before switchover.
x=$2
forceRsync=0
syncForSwitchover=0
go=""
# is x empty?  if not zero characters then look at the value
if [ ${#x} -ne 0 ]; then
   if [[ "${x}" == "f" || "${x}" == "F" ]]; then
      while true
      do
         # Need to read the input using the Korn shell syntax, not bash syntax.
         #read -p "Are you sure you want to force rsync from this site? [Y|y|N|n] :" go
         read -n 2 go?'Are you sure you want to force rsync from this site? [Y|y|N|n] : '
         go=$( echo ${go} | tr -d '[:cntrl:][:blank:]' )
         [[ ${go} = 'Y' || ${go} = 'y' || ${go} = 'N' || ${go} = 'n' ]] && break
         go=""
      done
      if [[ ${go} = 'N' || ${go} = 'n' ]]; then
         echo "You do not want to force rsync.  Exiting."
         Usage
         exit 1
      else
         echo "You do want to force the rsync.  Continuing."
         forceRsync=1
      fi
   elif [[ "${x}" == "s" || "${x}" == "S" ]]; then
      # This is for performing a final sync as part of switchover.
      syncForSwitchover=1
      echo "syncEBS.sh running in syncForSwitchover mode."
   else
      echo "syncEBS.sh: Your second parameter does not make sense."
      echo "Second parameter: ${x}"
      Usage
      exit 1
   fi
fi

}

################################################################################
# Usage:
# Standard usage clause
################################################################################
Usage()
{
echo "Usage: syncEBS.sh <driver file> [ F | f || S | s ] "
echo "       Required:"
echo "       <driver file> is an env file holding parameters needed for this run."
Echo "       Optional - either F or S:"
echo "       F or f will FORCE an rsync.  This should only be done if the primary"
echo "       database has CRASHED but you are able to manually synchronize the"
echo "       middle tier file system."
echo "       S or s triggers a fresh full rsync to be done.  It is called during "
echo "       a switchover to a new site."
echo "       NOTE: If you have a second parameter, it can be either F|f or S|s"
echo "       You cannot specify three parameters."
echo ""
}

################################################################################
# SetEnv
# Get environment variables, standard include routines
#
# Input:  None
# Output: Environments set for the run
# Return: Exit 1 if can't find environment files, etc.
################################################################################
SetEnv()
{

# Include the basic "where am I" environment settings
if [ ! -f ${SCRIPT_DIR}/ebsAppTier.env ]; then
   echo "Cannot find the file ${SCRIPT_DIR}/ebsAppTier.env."
   exit 1
fi

. ${SCRIPT_DIR}/ebsAppTier.env

# Include the standard functions routines
if [ ! -f ${SCRIPT_DIR}/stdfuncs.sh ]; then
   echo "Cannot find the standard functions script (stdfuncs.sh)"
   exit 1
fi

. ${SCRIPT_DIR}/stdfuncs.sh

# Include the environment settings for rsync to remote site
if [ ! -f ${SCRIPT_DIR}/ebsRsync.env ]; then
   echo "Cannot find the file ebsRsync.env."
   exit 1
fi

. ${SCRIPT_DIR}/ebsRsync.env

# Include the environment file they passed in
# this sets copyFiles and copyDirectories
if [ ! -f ${runEnv} ]; then
   echo "Cannot find the file ${runEnv}."
   Usage
   exit 1
fi

. ${runEnv}

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_syncEBS_${fsAlias}_${TS}.log

# This process creates a ton of little rsync scripts.
# Create the script directory if it doesn't already exist
if [ ! -d syncScripts_${fsAlias} ]; then
   mkdir syncScripts_${fsAlias}
fi

# do the config files exist?
if [[ ! -f ${copyDirectories} || ! -f ${excludeFiles} ]]; then
   LogMsg "Your config files holding directories to copy and files/directories to exclude must exist."
   LogMsg "They may be empty."
   exit 1
fi

}

################################################################################
# RunYesNo
# Is it ok to do this sync run?  This could be explicitly disabled, we could
# be at the standby, or there could be one already running.  If one of these
# is true, do not run.
# Note we force it to run during a switchover, in which case syncForSwitchover
# would be = 1.  This is managed in a separate script killSync.sh
#
#  Input: 
# Output: 
# Return: Exit if should not run, else proceed
################################################################################
RunYesNo()
{
LogMsg "RunYesNo: Is it appropriate to proceed?"
if [ -f ${SCRIPT_DIR}/.${fsAlias}_rsync_disabled ]; then
   if [ ${syncForSwitchover} == 0 ]; then
      LogMsg "RunYesNo: rsync is disabled at this site.  If appropriate, re-enable with enableRsync.sh"
      exit 0
   else
      LogMsg "RunYesNo: rsync is disabled but syncEBS.sh is running in syncForSwitchover mode."
      LogMsg "RunYesNo: This will run a final rsync."
   fi
fi

# is there a thread of this flavor already running at this site?
# exit if lock file present.  create lock file if not, and continue
LogMsg "RunYesNo: lock file: ${SCRIPT_DIR}/.${fsAlias}.lck"
if [ -f ${SCRIPT_DIR}/.${fsAlias}.lck ]; then
   LogMsg "RunYesNo: rsync is currently running for ${fsAlias}"
   LogMsg "RunYesNo: Clear the lock file ${SCRIPT_DIR}/.${fsAlias}.lck if need to resume post-crash"
   exit 0
else
   LogMsg "RunYesNo: Proceed - rsync is not running for ${fsAlias}"
   touch ${SCRIPT_DIR}/.${fsAlias}.lck
fi

GetLogon $dbSecretName
dbSecret=$LOGON

# Expensive, but need to check to be sure this database is PRIMARY
if [ ${forceRsync} = 0 ]; then
   LaunchCoroutine system $dbSecret $CDB_CONNECT_STRING

   sql="select rtrim(database_role) from v\$database;"
   role=`ExecSql "$sql"`

   if [ "${role}" != "PRIMARY" ]; then
      LogMsg "RunYesNo: This site is in ${role} role.  Only rsync from PRIMARY site."
      LogMsg "Clearing the lock for ${fsAlias}."
      rm ${SCRIPT_DIR}/.${fsAlias}.lck
      exit 1
   fi

   # We are not doing a forced sync and the site is in the PRIMARY role.
   # Start the killSync.sh process in the background if it's not already running.
   # We are doing this here because we assume the syncEBS.sh script is 
   # running on a server dedicated to the sync process, not a normal EBS
   # application server (else we would just kill a partially completed
   # sync process directly and move quickly to a final rsync)
   PROCESS_COUNT=$(ps -elf | grep "${APP_OWNER}" | grep -E "killSync.sh" | grep -v grep | wc -l )
   if [[ ${PROCESS_COUNT} -eq 0 && ${syncForSwitchover} -eq 0 ]]; then
      # specifying 10 seconds between checks
      nohup ${SCRIPT_DIR}/killSync.sh 10 >/dev/null 2>&1 &
      LogMsg "RunYesNo: killSync.sh process started by syncEBS.sh."
   fi
else
   # User specified "force".  Make sure ok by connecting to DB
   mode=`sqlplus -s /nolog <<EOF! 
   connect system/$dbSecret@${CDB_TNS_CONNECT_STRING} 
   set heading off 
   set feedback off 
   select rtrim(database_role) from v\$database; 
   exit 
EOF!
`
  mode1=$( echo "${mode}" | grep "PRIMARY|PHYSICAL STANDBY|SNAPSHOT STANDBY" )
   if [ ${#mode1} -ne 0 ]; then
      if [ "${mode1}" = "PRIMARY" ]; then
         break
      else
         LogMsg "RunYesNo: Not safe to copy files from this site when role is ${mode1}"
         exit 1
      fi
    else
      LogMsg "RunYesNo: Got an error from SQL*Plus connection.  Proceeding with FORCE"
      LogMsg "mode: $mode"
   fi
fi

}

################################################################################
# SyncFiles
# Make a fresh copy of individual files from source to target.  Need this due
# to having to drill into the EBS directory structure in order to chunk up the
# directories fine enough for good multi-threading
#
#  Input: File containing source and target files to copy
# Output: Copied files
# Return: Exit 1 if source files do not exist
################################################################################
SyncFiles()
{
# Need an empty file to contain generated commands.
# Ignore error if it's not there.
# Doing this outside the loop, to clear out possible historical artifacts.
# Could leave them in place, since the execution of the generated script is
# done within this routine (leaving the old file in place would not result
# in accidentally running an old set of commands).  Let the reader decide...
LogMsg "SyncFiles: Recreating syncFiles_${fsAlias}.sh"
rm syncFiles_${fsAlias}.sh 2>/dev/null
touch syncFiles_${fsAlias}.sh

# They may not need to copy files.  Do nothing if that's the case.
LogMsg "SyncFiles: Any files to copy?"
if [ -f ${copyFiles} ]; then
   # Build the copy file commands
   cat ${copyFiles} | while read Source Destination
   do
      # skip comments
      if [ "${Source}" != "#" ]; then
         # make sure the source is a file
         if [ ! -f "${Source}" ]; then
            echo "$0: ERROR: ${Source} is not a file."
            exit 1
         fi
         LogMsg "Source: ${Source}  Destination: ${Destination}"
         # for local testing:
         # echo "cp ${Source} ${Destination}" >> syncFiles_${fsAlias}.sh
         echo "scp ${Source} ${USER}@${targetHostIP}:${Destination}" >> syncFiles_${fsAlias}.sh
      fi
   done

   chmod u+x syncFiles_${fsAlias}.sh

   LogMsg "SyncFiles: Synchronizing flat files."
   ./syncFiles_${fsAlias}.sh

else
   LogMsg "SyncFiles: No files to copy: ${copyFiles} is empty"
fi

LogMsg "SyncFiles: completed"

}

################################################################################
# SyncDirectories
# Build commands to rsync directories from source to target.
#
# This will exclude files or directories based on matching patterns
#
# NOTE: easy command to find long list of directories in a folder:
# ls -l | grep ^d | awk '{print $NF}'
#
#  Input: File containing source and target directories to rsync 
# Output: Scripts to sync directories, file listing scripts
# Return: Warning if source directories do not exist
################################################################################
SyncDirectories()
{
LogMsg "SyncDirectories: Started"
# Need an empty file to contain generated commands
# ignore error if it's not there
rm ${fsAlias}.txt 2>/dev/null
touch ${fsAlias}.txt

counter=0

LogMsg "SyncDirectories: Building the driving text file for directories."
cat ${copyDirectories} | while read Source Destination
do
   # skip comments
   if [ "${Source}" != "#" ]; then
      # make sure the source is a directory
      if [ ! -d "${Source}" ]; then
         # If you just started using a new scheme for log and out directories
         # the directories may not yet exist - thus this is a warning, not
         # an error.  If you are confident your directories are in place,
         # make this an error with an exit 1.
         LogMsg "$0: Warning: Directory ${Source} does not exist."
      else
         ((counter++))
         command="find \"$Source\" -maxdepth 1 -mindepth 1 -type d -exec rsync -avPr --exclude-from \"$excludeFiles\" --delete \"{}\" \"${USER}@${targetHostIP}:${Destination}\" \;"
         # This version is for local testing:
         # command="find \"$Source\" -maxdepth 1 -mindepth 1 -type d -exec rsync -avPr --exclude-from \"$excludeFiles\" --delete \"{}\" \"$Destination\" \;"
         echo "${command}" > syncScripts_${fsAlias}/do_${counter}.sh
         chmod u+x syncScripts_${fsAlias}/do_${counter}.sh
         echo syncScripts_${fsAlias}/do_${counter}.sh >> ${fsAlias}.txt
      fi
   fi
done

LogMsg "SyncDirectories: ${counter} threads queued."

}

################################################################################
# Execution starts here.
################################################################################

ParseArgs $*
# Leave ParseArgs with copyDirectories set to the file holding the source
# and target directories, copyFiles (if present) set to a file holding specific
# files to copy

SetEnv

LogMsg "syncEBS.sh: Started"

# Is it appropriate to run at this time?
RunYesNo

# Did they provide a parameter pointing to a file holding a list of files
# to copy?
if [ "${copyFiles}" != "" ]; then
   SyncFiles
fi

# Build ${fsAlias}.txt, a text file containing rsync commands to sync
# lower-level directories
SyncDirectories

# Run the commands built by SyncDirectories.  MultiThread's parameters:
# name of driving file, # threads to kick off, grep phrase, # seconds to sleep
MultiThread ${fsAlias}.txt 15 syncScripts_${fsAlias} 3

# We're done.  Remove the lock file for the process.
rm ${SCRIPT_DIR}/.${fsAlias}.lck

LogMsg "Completed: syncEBS.sh"


