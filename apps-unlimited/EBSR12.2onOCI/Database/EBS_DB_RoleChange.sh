#!/bin/ksh
#############################################################################
# EBS_DB_RoleChange.sh
# Spawn the scripts to reconfigure EBS on the database RAC nodes if required.
#
# Note: This script blocks when running the txk configuration scripts, so 
#       errors are caught here instead of floating around in the ether.
# 
# Note: If the homes need to change: we're assuming all database instances
#       are visible in gv$instance when this is executed.  If an instance
#       is down, that home will not be reconfigured.
#
# Requires user equivalency across all RAC nodes.
#
# Things to ignore or be aware of:
# stty: standard input: Inappropriate ioctl for device
# The random creation of +DATAC1 in your script directory (bug#: ...)
# Creation of logs in your script directory named mmddhhmm.log
#
# No parameters passed in
#
# Rev:
# 8/28/24       MPratt   Simplified, added ksh coroutine for efficiency
# 1/15/24       DPresley Created
#############################################################################
#
. /home/oracle/EBSCDB.env
. ./EBSCFG.env
HostName=$(hostname)
MYHOST=$(hostname)

. ${CONTEXT_FILE}.env

# Call the standard functions routine
. $SCRIPT_DIR/stdfuncs.sh
  
# Include the common code for reconfiguring the path.  This will be 
# executed both from this script and from the spawned shell scripts on other DB
. $SCRIPT_DIR/ChangeHomePath.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_EBS_DB_RoleChange_${TS}.log

LogMsg "EBS_DB_RoleChange.sh: Started"

GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

# Start sqlplus in coroutine, logged in as apps user
LaunchCoroutine APPS $APPS_SECRET $PDB_TNS_CONNECT_STRING

GetDbName

sql="select XMLTYPE(t.text).EXTRACT('//ORACLE_HOME/text()').getStringVal() \
from apps.fnd_oam_context_files t     \
  where name = '` echo ${PDB_NAME}`_`echo ${THIS_HOSTNAME}`'	\
  and node_name = '`echo ${THIS_HOSTNAME}`'	\
  order by last_update_date desc	\
  fetch first row only;"
EBS_DB_OH=`ExecSql "${sql}"`

LogMsg "ORACLE_HOME: $ORACLE_HOME"
LogMsg "EBS_DB_OH: $EBS_DB_OH"

# Only spawn the jobs if the oracle home path is different
if [ "${ORACLE_HOME}" != "${EBS_DB_OH}" ]
# TESTING: DO IT IF IT'S THE SAME
# if [ "${ORACLE_HOME}" = "${EBS_DB_OH}" ]
then 
  LogMsg "Oracle home paths are different.  Reconfigure hosts"

  # Insert a row for each RAC node, then select those rows to drive the fix scripts.
  # Need the rows in the table so the middle tiers can see configuration is not
  # done yet across all instances.

  # Are we assuming all instances are up when this executes?  Why, yes, we are...

  sql="INSERT INTO apps.xxx_EBS_role_change (host_name,rolechange_date) \
  SELECT host_name, sysdate \
  FROM gv\$instance;
  commit;"
  ExecSql "${sql}"

  LogMsg "DB_HOSTS: $DB_HOSTS"
  LogMsg "MYHOST: $MYHOST"

  # DB_HOSTS is a configuration in your .env file
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

    sql="DELETE FROM apps.xxx_EBS_role_change where host_name='${i}';
         commit;"
    ExecSql "${sql}"
  done
fi

LogMsg "Completed: EBS_DB_RoleChange.sh."

