#!/bin/ksh
#############################################################################
# callReConfig.sh
# Call the scripts to reconfigure EBS on the database RAC nodes on remote 
# hosts.
# 
# Requires user equivalency across all RAC nodes.
#
# This script establishes the environment, gets the apps password.
# then executes ReConfig on remote hosts.  It's called remotely by 
# EBS_DB_RoleChange.sh
#
# Rev:
# 8/29/24       MPratt   Created
#############################################################################
#

# echo "callReConfig.sh: You got in"
# echo "HOSTNAME: $HOSTNAME"
mypath=`pwd`
echo "mypath: $mypath"

. /home/oracle/EBSCDB.env
. ${mypath}/EBSCFG.env
HostName=$(hostname)

. ${CONTEXT_FILE}.env

# Include the standard functions routines
. $SCRIPT_DIR/stdfuncs.sh

# Include the common code for reconfiguring the path.  This holds the
# code that is executed in this script for the DB nodes remote to the main
# driving script.
. $SCRIPT_DIR/ChangeHomePath.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_callReConfig_${TS}.log

LogMsg "callReConfig.sh: Started"

# Get the apps password - needs to be set before executing ReConfig
GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

# Don't need to do this - not executing sqlplus for anything here
# Start sqlplus in coroutine, logged in as apps user
# LaunchCoroutine APPS $APPS_SECRET $PDB_TNS_CONNECT_STRING

# for this script, ok to substitute HostName for DbName, which is used
# in LogMsg (else would need to launch the coroutine)
# GetDbName
DbName=$HostName

ReConfig

LogMsg "callReConfig.sh: Completed."

