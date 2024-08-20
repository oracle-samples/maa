#!/bin/bash
############################################################################
#
# File name:   stopPSFTAPP.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: This script shuts down PSFT app servers and process
#              schedulers.
#              It is also integrated with the rsync scripts.  However, the rsync integration is commented out
#              to prevent running rsync until you have completed all prerequisites.  Once the prerequisites 
#              have been met, then uncomment out the rsync integration code.
#
#              Note: Because this deployment of PeopleSoft uses a shared file
#              system for interface files, job logs, and reports, only one
#              rsync process should be running, and only one final execution 
#              after all app servers and process scheduler processes across
#              all nodes have completed their shutdown.
#
#              We use a simple lock file on the shared file system to
#              manage that process. The first script in creates the lock
#              file.  That session will also run the final rsync, then
#              will remove the lock file.
#
#              NOTE: If you do not want to run rsync but only shut down
#              either the app servers or the process scheduler, use the
#              individual scripts: 
#              stopAPP.sh and stopPS.sh
#
# Errors:      Any errors from dependent scripts.
#
############################################################################

source ~/psft.env
source "${SCRIPT_DIR}"/psrsync.env

HOSTNAME="$(hostname)"
DATE_TIME="$(date +"%Y%m%d_%H%M%S")"

# Check to see if the lock file exists.  if so, another stopPSTAPP.sh process is running and will perform the
# the final rsync.  Otherwise, create the lock file with THIS host name in it.
if [ -f "${SCRIPT_DIR}/psftrsync.lck" ]
then
     SKIP_RSYNC=1
else
     hostname > "${SCRIPT_DIR}"/psftrsync.lck
     SKIP_RSYNC=0
fi

# Stop application server and process scheduler.

"${SCRIPT_DIR}"/stopPS.sh  "${PS_PRC_DOMAIN}" > "${LOG_DIR}"/"${HOSTNAME}"_stopPS_"${DATE_TIME}".log 2>&1  &
"${SCRIPT_DIR}"/stopAPP.sh "${PS_APP_DOMAIN}" > "${LOG_DIR}"/"${HOSTNAME}"_stopAPP_"${DATE_TIME}".log 2>&1  &

# Uncomment the folloiwng code once you are ready to integrate the rsync scripts.
# If SKIP_RSYNC is 0, we must wait until all sessions have been shut down.
# We can then do one final rsync.
#
#
# if [ "${SKIP_RSYNC}" -eq 0 ]
# then
#  echo "Checking number of remaining sessions before performing rsync...."
#  SESSION_COUNT=1
#  while [ "${SESSION_COUNT}" -ne 0  ];
#  do
#     SESSION_COUNT=$("${SCRIPT_DIR}"/get_db_session_count.sh | sed 's/[^0-9]*//g')
#     echo "Number of remaining sessions: " ${SESSION_COUNT}
#     sleep 3
#  done
#
# Do one final rsync then disable rsync. If there is an existing rsync 
# process running, wait until the rsync process completes.
# We need to source the fs1 file to get the SOURCE_RSYNC_DIR env 
# variable set.
#
# Uncomment the below lines when you are ready to integrate the replicaton rsync scripts.
# Change the file systems files (fs1, fs2...) per your environment.

#   source $SCRIPT_DIR/fs1
#
#  pcount=1
#  while [ "$pcount" -gt 0 ]; 
#  do
#       pcount=$(ps -elf | grep "rsync -avzh --progress ${SOURCE_RSYNC_DIR}" | grep -v grep | wc -l)
#       sleep 3
#  done
#   
#  "${SCRIPT_DIR}"/rsync_psft.sh "$SCRIPT_DIR"/fs1
#  "${SCRIPT_DIR}"/disable_psft_rsync.sh "$SCRIPT_DIR"/fs1
#  "${SCRIPT_DIR}"/disable_psft_rsync.sh "$SCRIPT_DIR"/fs2
   rm -f "${SCRIPT_DIR}"/psftrsync.lck
# fi
