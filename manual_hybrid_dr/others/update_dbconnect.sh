#!/bin/bash

## hybrid_dr scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# This script can be used for replacing the connect string in the datasources (in folder ${ASERVER_HOME}/config/jdbc
# and in the jps config files (in folder ${ASERVER_HOME}/config/fmwconfig)
# Note this perform replacements in the files, so it must be used conscientiously.

# Provide the current string that is going to be replaced
# Example:
#export ORIGINAL_STRING='(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST= dbhost-scan.myopnetwork.com)(PORT=1521)))(CONNECT_DATA=(SERVICE_NAME= soapdb.myopnetwork.com)))'
export ORIGINAL_STRING=

# Provide the new db connect string that is going to be used (tns alias)
# Example:
#export NEW_STRING='soapdb'
export NEW_STRING=

# Check that ORIGINAL_STRING is defined
##################################################
if [ -z "$ORIGINAL_STRING" ]
then
        echo "Error: ORIGINAL_STRING not defined"
	exit 1
else
        echo "Previous db connect string.................... $ORIGINAL_STRING"
fi


# Check that NEW_STRING is defined
###################################################
if [ -z "$NEW_STRING" ]
then
        echo "Error: NEW_STRING not defined"
        exit 1
else
        echo "New db connect string.................... $NEW_STRING"
fi

# Check that ASERVER_HOME is defined
###################################################
if [ -z "$ASERVER_HOME" ]
then
        echo "Error: ASERVER_HOME not defined"
        exit 1
else
        echo "ASERVER_HOME ........................... $ASERVER_HOME"
fi




# Check that this is running by oracle
###################################################
if [ "$(whoami)" != "oracle" ]; then
        echo "Script must be run as user: oracle"
        exit 1
fi



date_label=$(date '+%d-%m-%Y-%H-%M-%S')

# Replace in the datasource files
#####################################################
cp -rf ${ASERVER_HOME}/config/jdbc   ${ASERVER_HOME}/config/jdbc_bck${date_label}
cd ${ASERVER_HOME}/config/jdbc
find . -name '*.xml' | xargs sed -i 's|'${ORIGINAL_STRING}'|'${NEW_STRING}'|gI'
echo "Replacement in ${ASERVER_HOME}/config/jdbc complete!"
echo ""

# Replace in the jps files
#####################################################
if [ -d "${ASERVER_HOME}/config/fmwconfig" ]; then
	cp -rf ${ASERVER_HOME}/config/fmwconfig   ${ASERVER_HOME}/config/fmwconfig_bck${date_label}
	cd ${ASERVER_HOME}/config/fmwconfig
	find . -name '*.xml' | xargs sed -i 's|'${ORIGINAL_STRING}'|'${NEW_STRING}'|gI'
	echo "Replacement in ${ASERVER_HOME}/config/fmwconfig  complete!"
	echo ""
fi

