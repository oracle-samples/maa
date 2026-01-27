#!/bin/ksh
############################################################################
# File name: run_EBS_shutdown.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# Description: This script shuts down EBS app servers and concurrent
# managers. This script calls run_EBS_stopServices.sh
# which does the actual shutdown of the application services.
# This script is integrated with the rsync scripts.
#
# Note: Because this deployment of EBS uses a shared file
# system for interface files, job logs, and reports, only one
# rsync process should be running, and only one final execution
# after all app servers and concurrent managers across
# all nodes have completed their shutdown.
#
# We use a simple lock file on the shared file system to
# manage that process. The first script in creates the lock
# file. That session will also run the final rsync, then
# will remove the lock file.
#
# NOTE: If you do not want to run rsync but only shut down
# either the app servers or the process scheduler, use the
# individual scripts:
# adstpall.sh and adstrtal.sh
#
# Usage: run_EBS_shutdown.sh
#
# Errors:
# Revisions:
# Date       What
# 09/03/2024 Updated for coroutines, tidying
# 7/1/2023   Created
############################################################################
mypath=`pwd`
echo "mypath: $mypath"

. ${mypath}/ebsrsync.env
HostName=$(hostname)

# Include the standard functions routines
. $SCRIPT_DIR/stdfuncs.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_runEBSshutdown_${TS}.log

LogMsg "run_EBS_shutdown.sh: Started"

# Set the apps env.
# LogMsg “NE_BASE: $NE_BASE”
if [ -f $NE_BASE/../EBSapps.env ]; then
  $NE_BASE/../EBSapps.env run
else
  LogMsg "EBS environment is not set.  Cannot find the file EBSapps.env.”
  exit 1
fi

# If there is already a lock file, another app server is taking care of rsync
if [ -f "${SCRIPT_DIR}/ebsrsync.lck" ]; then
   SKIP_RSYNC=1
else
   echo ${HOSTNAME} >> ${SCRIPT_DIR}/ebsrsync.lck
   SKIP_RSYNC=0
fi

# Run the shutdown scripts for this app server in the background.
${SCRIPT_DIR}/run_EBS_stopServices.sh | tee -a ${LOG_OUT} &

# If SKIP_RSYNC is 0, this session must make sure the file systems are synchronized.
# To do this, we must wait until all sessions have been shut down, and
# make sure there isn’t an rsync process already running. 
#  Wait for these two things to be true, then do one final rsync.
if [ ${SKIP_RSYNC} -eq 0 ]; then
   LogMsg “Wait for EBS DB connections to stop”
   # get DB connection going
   GetLogon $APPS_SECRET_NAME
   APPS_SECRET=$LOGON
   # Start sqlplus in coroutine, logged in as apps user
   LaunchCoroutine APPS $APPS_SECRET $PDB_TNS_CONNECT_STRING

   LogMsg "Checking number of remaining database sessions before performing rsync."
   sql=”select ltrim(count(*)) \
      from gv\$instance a, gv\$session b \
      where a.inst_id = b.inst_id \
      and service_name in ('VISPRD_OACORE_ONLINE','VISPRD_PCP_BATCH','VISPRD_FORMS_ONLINE');”
   ckRunDB 5

   # DB sessions all finished.  Now tackle final rsync.
   # If rsync is currently running, need to wait until it completes then 
   # start a fresh session to catch all remaining file changes
   # We need to source the appropriate file to get the SOURCE_RSYNC_DIR env
   # variable set.
   LogMsg “Check for possible rsync still running.  Let it finish.”
   . ${SCRIPT_DIR}/fs_APPLCSF
   ckRunOS ${SOURCE_RSYNC_DIR} 3

# Commented out:
  #  pcount=1
   # while [ $pcount -gt 0 ]; do
     # pcount=$(ps -elf | grep "rsync -avzh --progress ${SOURCE_RSYNC_DIR}" | grep -v grep | wc -l)
     # sleep 3
   # done

   # we know any already-running rsync scripts are complete.  Do one final sweep,
   # then disable rsync.
   ${SCRIPT_DIR}/rsync_ebs.sh ${SCRIPT_DIR}/fs_APPLCSF
   ${SCRIPT_DIR}/disable_ebs_rsync.sh ${SCRIPT_DIR}/fs_APPLCSF
   ${SCRIPT_DIR}/disable_ebs_rsync.sh ${SCRIPT_DIR}/fs1
   ${SCRIPT_DIR}/disable_ebs_rsync.sh ${SCRIPT_DIR}/fs2
   rm -f ${SCRIPT_DIR}/ebsrsync.lck
fi

LogMsg "run_EBS_shutdown.sh: Completed"
