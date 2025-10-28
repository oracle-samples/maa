#!/bin/ksh
################################################################################
# Name: stopEBS.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# Purpose: Stop EBS application tier in various ways, depending on need.
#          The basic tasks:
#          a. Stop EBS application services
#          b. Kill remainng services if any running after x time
#          c. Grab a lock for managing file system synchronization
#          d. Block until all EBS connections to DB are gone
#          e. Make sure replication is complete, do one last pass of shared
#             file system
#
#          The calling choices:
#          n: Normal: does a and b above
#          s: Switchover: does c, a, b, d, and e above
#
# Usage: stopEBS.sh [arguments]
#        n) Normal:
#              - Stop EBS application services
#              - Kill remaining services if any running after x time
#        s) Switch this environment to standby:
#              - Grab a lock for managing file system synchronization
#              - Stop EBS application services
#              - Kill remaining services if any running after x time
#              - Block until all EBS connections to DB are gone
#              - Make sure replication is complete, do one last pass of shared
#                file system
#
# ASSUMPTIONS: User has privileges to run EBS admin scripts.
#              User's environment is already set for EBS
#             ($NE_BASE/../EBSapps.env run has been executed)
#
# Errors: A non-zero value is returned for bad arguments, inability to
#         connect, ...
#
# Revisions:
# Date        What
# 09/10/2024  Consolidated earlier scripts into one
################################################################################
# ParseArgs:
# Parse the command line arguments
#
#  Input: command line arguments
# Output: run profile set, determining which routines are executed
# Return: exit 1 if arguments are no good
################################################################################
ParseArgs()
{
#
# Make sure at least 1 argument is present
if [ $# -lt 1 ]
then
   echo "$0: ERROR: You have entered insufficient arguments"
   Usage
   exit 1
fi

# make sure the parameter passed was correct
# set `getopt n:s: $*`
if [[ $1 = "n" || $1 = "s" ]]
then
   break
else
   echo "$0: ERROR: You have entered an incorrect argument"
   Usage
   exit 1
fi

#
# They sent in an n or s, which will drive behavior
#
runPlan=$1

}

################################################################################
# Usage:
# Standard usage clause
################################################################################
Usage()
{
echo "Usage: stopEBS.sh [mode]"
echo "Mode can be:"
echo "   n = Normal shutdown.  Stop EBS and make sure all DB cx are gone."
echo "   s = Switchover shutdown - \"Normal\" plus finalize replication before returning control."
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

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_stopEBS_${TS}.log

# Make sure the the apps env. is already set
if [ ! -f $NE_BASE/../EBSapps.env ]; then
   LogMsg "EBS environment is not set.  Cannot find the file EBSapps.env."
   LogMsg "NE_BASE: $NE_BASE"
   exit 1
fi

}

################################################################################
# GetCreds
# Get EBS and FMW credentials needed in this run
#
# Input:  None
# Output: The creds we need, set
# Return: 1 if can't find one of the users referenced
################################################################################
GetCreds()
{
LogMsg "Getting EBS credentials"
GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

GetLogon $WLS_SECRET_NAME
WLS_SECRET=$LOGON
}

################################################################################
# GetLock
# First app server to initiate the stop-to-switch-over process is responsible
# for making sure replication is complete / all file system changes are
# captured.
#
# That app server grabs a lock to make sure no one else does
# replication work.  Then it disables the rsync process so none will start
# in the background as we are shutting down.
#
# Input: None
# Output: If first in - create the lock file, set SKIP_RSYNC to 1,
#            and disable automatic rsyncs
#         If not, show which server has the lock and set SKIP_RSYNC to 0
# Return: None
################################################################################
GetLock()
{
LogMsg "GetLock: Looking for $SCRIPT_DIR/ebsrsync.lck"

if [ -f "${SCRIPT_DIR}/ebsrsync.lck" ]; then
   SKIP_RSYNC=1
   LogMsg "GetLock: Someone else is managing rsync shutdown"
else
   echo ${HOSTNAME} >> ${SCRIPT_DIR}/ebsrsync.lck
   SKIP_RSYNC=0
   LogMsg "GetLock: This process will manage rsync shutdown"

   thing=`cat ${SCRIPT_DIR}/ebsrsync.lck`
   LogMsg "GetLock: Contents of lock file: ${thing}"

   LogMsg "GetLock: Disable rsync so we won't start a fresh session."
   ${SCRIPT_DIR}/disable_ebs_rsync.sh ${SCRIPT_DIR}/slowFiles.env
   ${SCRIPT_DIR}/disable_ebs_rsync.sh ${SCRIPT_DIR}/fastFiles.env
   # Trigger the killSync process to terminate any running rsyncs.
   # We have to do this via shared file system because stopEBS.sh will be run
   # on a server that hosts EBS, but the rsync processes should be on dedicated
   # servers.
   # If an in-progress rsync processes are killed, rsync is robust enough to not 
   # replace a file until it is completely copied to its target.

   LogMsg "GetLock: Trigger killSync to stop any running rsync processes."
   # List the file system env files below and before the EOF.
   cat <<EOF >> ${SCRIPT_DIR}/.abortSync
   ${SCRIPT_DIR}/fastFiles.env
   ${SCRIPT_DIR}/slowFiles.env
EOF

fi
}

################################################################################
# ConnectDB
# Launch the coroutine.  Need for t and s only
#
# Input:  None
# Output: SQL*Plus child process initiated 
# Return: 1 if can't start sqlplus in the background
################################################################################
ConnectDB()
{
LogMsg "ConnectDB: LaunchCoroutine"

# Start sqlplus in coroutine, logged in as apps user
LaunchCoroutine APPS $APPS_SECRET $PDB_TNS_CONNECT_STRING

LogMsg "SQLPlus coroutine started"
}

################################################################################
# BlockUntilGone
# Part of shutting down for switchover: wait until all EBS client sessions
# have ended.  Look for service names that are configured for any EBS user
# session.  In our system: VISPRD_OACORE_ONLINE, VISPRD_PCP_BATCH, and
# VISPRD_FORMS_ONLINE 
#
# Input:  None
# Output: Number of DB instances needing reconfig, sleep time, dividing line
# Return: 1 if can't start sqlplus in the background
#           if no sleep time
#           if $sql is empty
################################################################################
BlockUntilGone()
{
LogMsg "stopEBS.sh: Checking number of remaining database sessions before performing rsync."
sql="select ltrim(count(*)) \
   from gv\$instance a, gv\$session b \
   where a.inst_id = b.inst_id \
   and service_name in ('VISPRD_OACORE_ONLINE','VISPRD_PCP_BATCH','VISPRD_FORMS_ONLINE');"
CkRunDB 5

LogMsg "All EBS user sessions ended - ok to proceed."
}

################################################################################
# StopServices
# Request a clean exit for all EBS application services on the middle tiers.
#
# Input:  None
# Output: Request for stopping EBS application \ middle tiers on all app servers
# Return: 1 if can't start sqlplus in the background
################################################################################
StopServices()
{
LogMsg "StopServices: Stopping EBS on all application servers"

{ echo "APPS"; echo "$APPS_SECRET"; echo "$WLS_SECRET"; } | $ADMIN_SCRIPTS_HOME/adstpall.sh | tee -a ${LOG_OUT}

# Did adstpall report failure?
if [ $? -ne 0 ]; then
  LogMsg "StopServices: $ADMIN_SCRIPTS_NAME/adstpall.sh reported failure."
  exit 1
fi

LogMsg "Completed: StopServices."
}

################################################################################
# KillSessions
# The prior routine asked EBS to properly terminate all EBS sessions.  This 
# routine pauses progress if anything is still running.  It checks a couple of
# times, after a bit loses patience and just kills what's left.
#
# NOTE: PARAMETERIZE THIS or adjust things like number of seconds 
# 
# Input:  None
# Output: EBS application and middle tiers fully down on all app servers
# Return: None
################################################################################
KillSessions()
{
LogMsg "KillSessions: Wait for sessions to complete.  Kill after x number of tries."
LogMsg "Return control as soon as possible so we can proceed with next steps."

PROCESS_COUNT=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | wc -l )
LogMsg "KillSessions: Number of remaining processes: ${PROCESS_COUNT}"
i=1
while [ ${PROCESS_COUNT} -ne 0 ];
do
  # Sleep for 10 seconds to let some processes terminate.
  sleep 10
  PROCESS_COUNT=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | wc -l )
  # PID_LIST=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | awk '{ print $4 }' )
  Running=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep )
  LogMsg "${PROCESS_COUNT} remaining processes: ${Running}"
  if [[ $i -gt 3 && ${PROCESS_COUNT} -ne 0 ]]; then
    # we have only so much patience
    PID_LIST=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | awk '{ print $4 }' )
    LogMsg "stopEBS.sh: Killing processes: ${PID_LIST}"
    kill -9 ${PID_LIST}
    # we're assuming they're dead now.  This breaks us out of the while loop.
    PROCESS_COUNT=0
  fi
  ((i=i+1))
done
LogMsg "stopEBS.sh: All EBS services down on this server."

LogMsg "Completed: KillSessions."
}

################################################################################
# CompleteReplication
# DB sessions all finished.  Now tackle final rsync.
#
# Rsync was disabled earlier, but there still might be an rsync process
# running on the dedicated servers.  Check; if so, wait for it to complete.
#
# Finally, do a cleanup rsync of fastFiles directory structure.
#
# We need to source the appropriate file to get the SOURCE_RSYNC_DIR env
# variable set.  We are assuming it's appropriate to check only for fastFiles
# replication...
#
# Input:  None
# Output: Updates on checking for rsync script locks
# Return: None
################################################################################
CompleteReplication()
{
LogMsg "CompleteReplication: Checking for running rsync processes via their lock file."

# do we want to wait forever?  these processes can run a very long time, or 
# our lock system could be broken
# Note: we are now killing the rsync processes in a separate process 
# (killSync.sh), so the final sweep can be started sooner.
while true; do
   if [ -f ${SCRIPT_DIR}/.slowFiles.lck | -f ${SCRIPT_DIR}/.fastFiles.lck ]; then
      LogMsg "One of the lock files is present."
      LogMsg "Sleeping..."
      LogMsg "======================================================================================"
      sleep 5
   else
      # we know any already-running rsync scripts are complete.  Do one final sweep.
      # Here, we just sync output files. You may choose to also sync program 
      # directories.
      LogMsg "All locks are clear.  Do one final sweep of fastFiles"
      ${SCRIPT_DIR}/syncEBS.sh ${SCRIPT_DIR}/fastFiles.env s
      LogMsg "CompleteReplication: Succeeded"
      break
   fi
done

}

################################################################################
# Execution starts here.
################################################################################

ParseArgs $*
# Leave ParseArgs with runPlan set to n or s

SetEnv

LogMsg "runPlan: $runPlan"

LogMsg "stopEBS.sh: Started"

GetCreds

# Check this for remaining EBS sessions
GREP_STRING="visprd|FNDLIB|FNDIMON|PALIBR"

# Remember: SKIP_RSYNC is set to 0 if you do NOT want to skip rsync,
# but instead WANT to do rsync, and to 1 if you DO want to skip rsync.
# Only the first server in has that flag set to 0 THUS DOES the rsync
case $runPlan in
   n) LogMsg "Normal shutdown"
      StopServices
      KillSessions
      ;;
   s) LogMsg "Switch away from this environment"
      GetLock
      StopServices
      KillSessions
      ConnectDB
      BlockUntilGone
      [ ${SKIP_RSYNC} == 0 ] && CompleteReplication
      [ ${SKIP_RSYNC} == 0 ] && rm ${SCRIPT_DIR}/ebsrsync.lck
      ;;
   *) Usage
      exit 1
      ;;
esac

LogMsg "Completed: stopEBS.sh"



