#!/bin/ksh
#############################################################################
# callReConfig.sh
# 
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
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
# 06/18/2025  No hard-coding to find env files
# 08/29/2024  Created
#############################################################################

mypath=`pwd`

. $HOME/EBSCDB.env
. ${SCRIPT_DIR}/EBSCFG.env
HostName=$(hostname)

. ${CONTEXT_ENV_FILE}

# Include the standard functions routines
. ${SCRIPT_DIR}/stdfuncs.sh

# Include the common code for reconfiguring the path.  This holds the
# code that is executed in this script for the DB nodes remote to the main
# driving script.
. ${SCRIPT_DIR}/ChangeHomePath.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_callReConfig_${TS}.log

LogMsg "callReConfig.sh: Started"

# Get the apps password - needs to be set before executing ReConfig
GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

# Note: we are not executing sqlplus for anything in this script, so are
# not launching the coroutine.  Side effect: for this script, we need
# to substitute HostName for DbName, which is used in LogMsg
# GetDbName
DbName=$HostName

# Finally - do the work:
ReConfig

LogMsg "callReConfig.sh: Completed."

