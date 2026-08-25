################################################################################
# Name: killSync.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# Purpose: Kill any already-running file sync processes if we are doing a
#          switchover.
#
#          killSync.sh is started by syncEBS.sh when running at the primary
#          site.  It runs in the background.  There is no user interaction.
#          Script behavior is managed through the use of shared files.
#	
# Usage:  killSync.sh [ sleep time in seconds ]
#
#  Errors: 
#          - if env files do not exist.  See SetEnv.
#          - if the file system alias was not specified.
#
# Revisions:
# Date        What
# 05/23/2025  Created
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

# The environment variable SCRIPT_DIR must be defined in the 
# OS user's .bash_profile or an environment file that is 
# sourced during logon from cron or other agents that may
# access the user's OS account to execute commands.

# Include the basic "where am I" environment settings
if [ ! -f ${SCRIPT_DIR}/ebsAppTier.env ]; then
   echo "Cannot find the file ${SCRIPT_DIR}/ebsAppTier.env."
   exit 1
fi

. ${SCRIPT_DIR}/ebsAppTier.env

# include the standard functions routines
if [ ! -f ${SCRIPT_DIR}/stdfuncs.sh ]; then
   echo "Cannot find the standard functions script (stdfuncs.sh)"
   exit 1
fi

. ${SCRIPT_DIR}/stdfuncs.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_killSync_${TS}.log

}

################################################################################
# ChkAbort()
# Check for the presence of the .abortSync file and checks its content.  
# Return the a value to the calling routine. 
#
# Input:  None
# Output: Environments set for the run
# Return: The content of the file if an abort is to be initiated
################################################################################
ChkAbort()
{

# Check to see if the .abortSync file is present.
if [ -f ${SCRIPT_DIR}/.abortSync ]; then
   chkrc=$( cat ${SCRIPT_DIR}/.abortSync | wc -l )
  
   # Check to see if any of the .env files do not exists. If there is a missing
   # env file, exit as we do not want to proceed.
   if [ ${chkrc} -ne 0 ]; then

      for i in $( cat ${SCRIPT_DIR}/.abortSync )
      do
         if [ ! -f ${i} ];
            then
            LogMsg "ChkAbort: ENV file: ${i} does not exist."
            LogMsg "Exiting..."
            exit 1
         fi
      done

   else
      LogMsg "ChkAbort: No env file specified."
      LogMsg "Exiting...."
      exit 1
   fi
fi

}

################################################################################
# KillSync
#
# NOTE: PARAMETERIZE THIS
#
# Input:  None
# Output: Kill any and all rsync and syncEBS processes and remove the locks.
#         This allows for a full final sync to take place once all processes
#         on all app servers are down.
# 
# Return: None
################################################################################
KillSync()
{

LogMsg "KillSync: Started."

# The .abortSync file will have the list of the env files that will provide the fsAlias we need. 
for i in $( cat ${SCRIPT_DIR}/.abortSync )
do
   if [ ! -f ${i} ]; 
   then
      LogMsg "KillSync:  ENV file: ${i} does not exists."
      LogMsg "KillSync:  Continuing...."
   else
      # Source the env file.
      . ${i}
   fi

   # The fsAlias variable is defined once the env file has been source.
   GREP_STRING="${fsAlias}"

   LogMsg "KillSync: Terminating existing rsync processes for ${fsAlias}."

   PROCESS_COUNT=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | wc -l )
   LogMsg "KillSync: Number of remaining processes: ${PROCESS_COUNT}"
   while [ ${PROCESS_COUNT} -ne 0 ];
   do
     Running=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep )
     LogMsg "${PROCESS_COUNT} remaining processes: ${Running}"
     PID_LIST=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | awk '{ print $4 }' )
     LogMsg "KillSync: Killing processes: ${PID_LIST}"
     kill -9 ${PID_LIST}
     PROCESS_COUNT=$(ps -elf | grep "${APP_OWNER}" | grep -E "${GREP_STRING}" | grep -v grep | wc -l )
   done

   # Remove the lck files.

   if [ -f ${SCRIPT_DIR}/.${fsAlias}.lck ]; then
      rm ${SCRIPT_DIR}/.${fsAlias}.lck
   fi

done 

LogMsg "KillSync: Completed."

}

################################################################################
# Execution starts here.
################################################################################

SetEnv

SLEEP_TIME_SEC=$1

if [ -z ${SLEEP_TIME_SEC} ]; then
   SLEEP_TIME_SEC=15
fi

LogMsg "killSync.sh: Started."
LogMsg "Sleep time ${SLEEP_TIME_SEC} seconds..."

while true 
do
   chkrc=0
   # ChkAbort will set the fsAlias variable if an abort was triggered.
   ChkAbort

   if [ ${chkrc} -ne 0 ]; then
      LogMsg "killSync.sh: Received Abort-Sync.  "
      KillSync  
      rm ${SCRIPT_DIR}/.abortSync
      break
   fi
   sleep ${SLEEP_TIME_SEC}
done

LogMsg "killSync.sh: Shutdown completed."


