#!/bin/bash

## dg_setup_scripts version 2.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# Load environment specific variables
if [ -f DG_properties.ini ]; then
        . DG_properties.ini
else
        echo "ERROR: DG_properties.ini not found"
        exit 1
fi

#Check that this is running by oracle root
if [ "$(whoami)" != "root" ]; then
        echo "Script must be run as user: root"
        exit 1
fi

# The full path in ASM of the password file
export PWFILE_ASM=$A_FILE_DEST/$A_DBNM/PASSWORD/orapw${DB_NAME}
#export PWFILE_ASM=+DATAC1/CDB11/PASSWORD/pwdcdb11.256.1035458887

#################################################################################
echo ""
echo "This script will create a tar containing the primary DB password file"
echo "Checking that the password file exists in ${PWFILE_ASM} ...."
su - ${GRID_OSUSER} -c "$GRID_HOME/bin/asmcmd ls ${PWFILE_ASM}"
result=$?
if [[ $result != "0" ]]; then
	echo ""
        echo "ERROR: the password file ${PWFILE_ASM} not found"
	echo "If your password file has another name, please edit this script and modify the variable PWFILE_ASM with the path"
        exit 1
fi

echo ""
echo "Extracting password file from ASM..."
if [[  -f /tmp/orapw${DB_NAME} ]]; then
	rm /tmp/orapw${DB_NAME}
fi
su - ${GRID_OSUSER} -c "$GRID_HOME/bin/asmcmd cp ${PWFILE_ASM}  /tmp/orapw${DB_NAME}"
if [[ ! -f /tmp/orapw${DB_NAME} ]]; then
	echo ""
	echo "Error: could not copy password file from ${PWFILE_ASM}"
	echo "If your password file has another name, please edit this script and modify the variable PWFILE_ASM with the correct path"
	exit 1
fi

echo ""
echo "Creating password file tar in ${OUTPUT_PASWORD_TAR} ..."
cd /tmp
tar -czf ${OUTPUT_PASWORD_TAR} orapw${DB_NAME}
chown $ORACLE_OSUSER ${OUTPUT_PASWORD_TAR}
echo "Password file tar created!"
