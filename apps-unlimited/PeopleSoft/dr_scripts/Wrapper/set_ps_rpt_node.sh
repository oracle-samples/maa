#!/bin/bash
############################################################################
#
# File name:    set_ps_rpt_node.sh    Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Sets the distribution node for the process scheduler.  Called by startPSFTAPP.sh.
#              This script is site-specific and should be modified according to each site.  
# 
# NOTE:        OCI CLI must be installed for this script to run.
#
# Usage:       set_ps_rpt_node.sh
# 
# Errors:      Can return a database error (ORA-XXXXX) if database is 
#              unavailable or there is access failure.
#
############################################################################

source ~/psft.env
source "${SCRIPT_DIR}"/psrsync.env
source "${SCRIPT_DIR}"/ps_rpt.env


date +"%d-%b-%Y %T"
echo "Running set_ps_rpt_node.sh"
echo ""

SECRET_OCID=$(oci vault secret list -c "$COMPARTMENT_OCID" --raw-output --query "data[?\"secret-name\" == '$SECRET_NAME'].id | [0]")
PSFT_SECRET=$(oci secrets secret-bundle get --raw-output --secret-id "$SECRET_OCID" --query "data.\"secret-bundle-content\".content" | base64 -d )

echo "URL = ${URL}"
echo "RPT_URI =  ${RPT_URI}"

# Update the PS_CDM_DIST_NODE table to set the site specific report 
# distribution node. 
sqlplus -s /nolog  <<EOF!
connect sys/${PSFT_SECRET}@${TNS_CONNECT_STRING} as sysdba
alter session set container = "${PDB_NAME}";
set heading off
set define off
set feedback on
update "${SCHEMA_NAME}".PS_CDM_DIST_NODE
   set URL = '${URL}',
       URI_HOST = '${RPT_URL_HOST}',
       URI_PORT = ${RPT_URI_PORT},
       URI_RPT = '${RPT_URI}';

commit;

exit
EOF!
