#!/bin/bash

## PaaS DR scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# $1 Previous service name
# $2 New service name
# Usage
#        updateDBServiceName.sh  <previous_servicename> <new_servicename> 
#        ./updateDBServiceName.sh 
# This script updates the connection string in the datasources and in jps files.
# This script needs to be run in the admin node of the domain.
# A complete restart of the domain (admin and managed servers) is required for the change to be effective.
# Note this perform replacements in the files, so it must be used conscientiously.

if [ $# -lt 2 ]
  then
    echo "Insufficient arguments supplied"
    echo "Usage:"
    echo "updateDBServiceName.sh  <previous_pdbservicename> <new_pdbservicename>"
    exit 1
fi

if [ -z "${DOMAIN_HOME}" ]
then
      echo "\$DOMAIN_HOME is empty. Define the variable. Example: export DOMAIN_HOME=/u01/data/domains/my_domain"
      exit 1
else
      echo "\$DOMAIN_HOME is................." ${DOMAIN_HOME}
fi

export OLSDBSERVICE=$1
export NEWDBSERVICE=$2
export dt=$(date +%y%m%d_%H_%M_%S)


# Backup and update service name in datasources
echo " -------------------------------------------------------------"
echo " Replacing service name in ${DOMAIN_HOME}/config/jdbc files..."
echo " From previous service name : $OLSDBSERVICE "
echo " To new service name: $NEWDBSERVICE "
echo " -------------------------------------------------------------"
cd ${DOMAIN_HOME}/config
cp -rf jdbc jdbc_$dt
cd ${DOMAIN_HOME}/config/jdbc
find . -name '*.xml' | xargs sed -i 's|'${OLSDBSERVICE}'|'${NEWDBSERVICE}'|gI'

# Backup and update db service name in jps config files
echo " -------------------------------------------------------------"
echo " Replacing service name in ${DOMAIN_HOME}/config/fmwconfig files..."
echo " From previous service name : $OLSDBSERVICE "
echo " To new service name: $NEWDBSERVICE "
echo " -------------------------------------------------------------"
if [ -d "${DOMAIN_HOME}/config/fmwconfig" ]; then
	cd ${DOMAIN_HOME}/config
	cp -rf fmwconfig fmwconfig_$dt
	cd ${DOMAIN_HOME}/config/fmwconfig
	find . -name '*.xml' | xargs sed -i 's|'${OLSDBSERVICE}'|'${NEWDBSERVICE}'|gI'
fi

echo " Replacement finished"
echo " WARNING: A domain restart is required for these changes to take effect"

