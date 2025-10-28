#!/bin/ksh
#############################################################################
# startDBServices.sh
# Start any services that do not start when the PDB is opened, either because
# they are not managed by CRS or they are defined within a pluggable database
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# This script should only be used to start services that are:
# - not defined in CRS
# - defined only in a PDB
# - may not start when the database and PDB it is defined in opens.
#
# This script connects to the database using the PDB's default service, one
# that is always started when the PDB is opened.  This login is never used by
# end users - it is only used to start the services that end users use.
#
# This work is only needed on switchover if your environment uses the TNS
# configuration the PDB home instead of in the grid home.
#
# No parameters passed in.
#
# Rev:
# 06/18/2025  Removed hard-coding of call to environment-specific code
# 6/3/2025    Created.
#############################################################################
#
. $HOME/EBSCDB.env
. ${SCRIPT_DIR}/EBSCFG.env
HostName=$(hostname)
MYHOST=$(hostname)

# Call the standard functions routine
. $SCRIPT_DIR/stdfuncs.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_startDBServices_${TS}.log

LogMsg "startDBServices.sh: Started"
LogMsg "Starting database services ${EBS_DEFAULT_SERVICE_NAME} from node: ${MYHOST}"

GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

# Connect to the PDB using sqlplus, building the connect string to
# access the default PDB service
output_str=`sqlplus -s /nolog <<EOF!
connect ${APPS_USERNAME}/${APPS_SECRET}@${SCAN_NAME}:${SCAN_LISTENER_PORT}/${PDB_NAME}
exec dbms_service.start_service('${EBS_DEFAULT_SERVICE_NAME}',DBMS_SERVICE.ALL_INSTANCES);
exit
EOF!
`
# Were you able to connect?
tmp_str=$( echo "${output_str}" | grep -i "ERROR|ORA-|SP2-" )
if [ ${#tmp_str} -ne 0 ]; then
   LogMsg "An error occurred while attemping to start database services ${EBS_DEFAULT_SERVICE_NAME}:"
   LogMsg "${output_str}"
   exit 1
fi

LogMsg "Result of sqlplus session: ${output_str}"
LogMsg "startDBServices.sh: Completed."

exit 0

