############################################################################
#!/bin/sh
# File name:    get_site_role.sh    Version 1.0
#
# Copyright (c) 2022 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Determine whether this is the primary or a standby site
# 
# Notes:       This script requires oci cli be installed on the server it runs on. 
#
# Usage:       get_site_role.sh
# 
# Errors:      Can return a database error (ORA-XXXXX) if database is unavailable or access failure.
#
# Revisions:
# Date       Who       What
# 7/1/2023   DPresley  Created
############################################################################

source ~/psft.env
source $SCRIPT_DIR/psrsync.env

date +"%d-%b-%Y %T"
echo "Running get_site_role.sh"
echo ""

export SECRET_OCID=$(oci vault secret list -c $COMPARTMENT_OCID --raw-output --query "data[?\"secret-name\" == '$SECRET_NAME'].id | [0]")
export PSFT_SECRET=$(oci secrets secret-bundle get --raw-output --secret-id $SECRET_OCID --query "data.\"secret-bundle-content\".content" | base64 -d )

sqlplus -s /nolog  <<EOF!
connect sys/${PSFT_SECRET}@${TNS_CONNECT_STRING} as sysdba
set heading off
set feedback off
select rtrim(database_role) from v\$database;
exit
EOF!
