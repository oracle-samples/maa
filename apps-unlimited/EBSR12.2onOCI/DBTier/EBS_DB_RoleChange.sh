#!/bin/ksh
#############################################################################
# EBS_DB_RoleChange.sh
# Spawn the scripts to reconfigure EBS on the database RAC nodes if required.
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# Note: This script blocks when running the txk configuration scripts, so 
#       errors are caught here instead of floating around in the ether.
# 
# Note: If the homes need to change: We're assuming all database instances
#       are visible in gv$instance when this is executed.  If an instance
#       is down, THAT HOME WILL NOT BE RECONFIGURED.
#
# Requires user equivalency across all RAC nodes.
#
# Things to ignore or be aware of:
# stty: standard input: Inappropriate ioctl for device.  Irritating but
#       benign.
# The random creation of +DATAC1 in your script directory (bug#: .38086306)
# Creation of logs in your script directory named mmddhhmm.log
#
# No parameters passed in
#
# Rev:
# 06/18/2025 Using info in .profile to build environment, adjusted comments
# 04/28/25   Added check for logical hostnames.
# 8/28/24    Simplified, added ksh coroutine for efficiency
# 1/15/24    Created
#############################################################################
# Set up the environment variables
. $HOME/EBSCDB.env
. ${SCRIPT_DIR}/EBSCFG.env
. ${CONTEXT_ENV_FILE}

HostName=$(hostname)
MYHOST=$(hostname)

# Call the standard functions routine
. $SCRIPT_DIR/stdfuncs.sh

# Include the common code for reconfiguring the path.  This will be 
# executed both from this script and from the spawned shell scripts on
# other RAC DB nodes
. $SCRIPT_DIR/ChangeHomePath.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_EBS_DB_RoleChange_${TS}.log
LogMsg "EBS_DB_RoleChange.sh: Started"

# OPTIONAL, and commented out here:
# Start any required database services that do not get started automatically
# by CRS, or that are defined only in the PDB itself.
# IF THIS IS REQUIRED IN YOUR ENVIRONMENT, uncomment the code for
# running $SCRIPT_DIR/startDBServices.sh.
# More complete explanation in startDBServices.sh.

# This work is done with the default DB login - can't use the EBS database
# login data for this.

# First, check if the service might already be up.
if [ s=$(lsnrctl status | grep -i ebs_${PDB_NAME} | wc -l ) -eq 0 ]; then
    $SCRIPT_DIR/StartDBServices.sh
    if [ $? -ne 0 ]; then
       LogMsg "Attempt to start database services failed."
       LogMsg "Refer to log files in ${LOG_DIR}."
       exit 1
    fi
    else
       LogMsg "Service ebs_${PDB_NAME} is already up."
fi

# Continue with setup
GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

# Start sqlplus in coroutine, logged in as apps user
LaunchCoroutine APPS $APPS_SECRET $PDB_TNS_CONNECT_STRING

GetDbName

# Main flow:
# What does EBS think my oracle home path is?
sql="select XMLTYPE(t.text).EXTRACT('//ORACLE_HOME/text()').getStringVal() \
from apps.fnd_oam_context_files t  \
  where name = '` echo ${PDB_NAME}`_`echo ${THIS_HOSTNAME}`'  \
  and node_name = '`echo ${THIS_HOSTNAME}`'  \
  order by last_update_date desc  \
  fetch first row only;"
EBS_DB_OH=`ExecSql "${sql}"`

LogMsg "ORACLE_HOME: $ORACLE_HOME"
LogMsg "EBS_DB_OH: $EBS_DB_OH"

# Only spawn the jobs if the oracle home path is different
# If the path is the same, the bulk of this work is skipped
if [ "${ORACLE_HOME}" != "${EBS_DB_OH}" ]
then 
  LogMsg "Oracle home paths are different.  Reconfigure hosts"

  # Insert a row for each RAC node, then select those rows to drive the fix scripts.
  # Need the rows in the table so the middle tiers can see configuration is not
  # done yet across all instances.

  # We have both the list of hosts in DB_HOSTS and the list of hosts 
  # that have been restarted so far.  This code is a bit simplistic and assumes
  # they are the same.  For a  larger environment, enhance this to be sure the
  # count of the two is the same.

  sql="INSERT INTO apps.xxx_EBS_role_change (host_name,rolechange_date) \
  SELECT host_name, sysdate \
  FROM gv\$instance;
  commit;"
  ExecSql "${sql}"

  LogMsg "All DB_HOSTS: $DB_HOSTS"
  LogMsg "This database server: MYHOST: $MYHOST"

  # DB_HOSTS is a field in your .env file that holds the names of
  # of every database host in your RAC setup
  for i in ${DB_HOSTS}
  do
    if [ "${i}" == "${MYHOST}" ];
    then
      LogMsg "Configuring database homes for EBS on local host ${i}"
      ReConfig 
    else
      LogMsg "Configuring database homes for EBS on remote host: ${i}"
      LogMsg "ssh -t oracle@${i} cd ${SCRIPT_DIR}; ${SCRIPT_DIR}/callReConfig.sh"
      ssh -t oracle@${i} "cd ${SCRIPT_DIR}; ${SCRIPT_DIR}/callReConfig.sh"
    fi

    # all done - remove the rows driving the work
    sql="DELETE FROM apps.xxx_EBS_role_change where host_name='${i}';
         commit;"
    ExecSql "${sql}"
  done
fi

LogMsg "Completed: EBS_DB_RoleChange.sh."


