#!/bin/bash
############################################################################
#
# File name:    get_db_session_count.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description:  Get the total number of application session connections.  The query below counts session connections using database services.
#               HR92U033_BATCH is the database service used by the PeopleSoft process (batch) scheduler in our case study environment.
#               HR92U033_ONLINE is the database service used by the PeopleSoft application server for online users in our case study environment.
#               Edit the query below and change the service names according to your environment.  
#
# Parameters:   None
# 
# Output:       Returns only the number of sessions.  
#
# Errors:       Can return a database error (ORA-XXXXX) if database is unavailable or access failure.
#
# Notes: This script requires oci cli be installed
#
############################################################################

source ~/psft.env
source "$SCRIPT_DIR"/psrsync.env

SECRET_OCID=$(oci vault secret list -c "$COMPARTMENT_OCID" --raw-output --query "data[?\"secret-name\" == '$SECRET_NAME'].id | [0]")
PSFT_SECRET=$(oci secrets secret-bundle get --raw-output --secret-id "$SECRET_OCID" --query "data.\"secret-bundle-content\".content" | base64 -d )

sqlplus -s /nolog  <<EOF!
connect sys/${PSFT_SECRET}@${TNS_CONNECT_STRING} as sysdba
set heading off
set feedback off
select ltrim(count(*))
from gv\$instance a, gv\$session b
where a.inst_id = b.inst_id
and service_name in ('HR92U033_BATCH','HR92U033_ONLINE')
/
exit
EOF!
