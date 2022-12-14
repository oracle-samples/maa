#!/bin/bash

## ./fmwadbs_get_ds_property.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

### This script returns the value of a specific datasource property in a WLS/SOA/FMW datasource
##
### Usage:
###         ./fmwadbs_get_ds_property.sh [DATASOURCE_FILE] [DATASOURCE_PROPERTY]
###
### Where:
###	DATASOURCE_FILE 	The WLS jdbc datasource file (complete path)
###	DATASOURCE_PROPERTY	The key in datasource file

### EXAMPLE: (notice the escapes before $ and ')

### ./fmwadbs_get_ds_property.sh  /u01/data/domains&my_domain/config/jdbc/opss-datasource-jdbc.xml oracle.net.tns_admin

if [[ $# -eq 2 ]]; then
	export DATASOURCE_FILE=$1
        export DATASOURCE_PROPERTY=$2
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 2, got $#"
	echo "Usage :"
	echo "    $0  DATASOURCE_FILE DATASOURCE_PROPERTY"
	echo "Example:  "
	echo "    $0  '/u01/data/domains&my_domain/config/jdbc/opss-datasource-jdbc.xml' 'oracle.net.tns_admin'"
	echo ""
	exit 1
fi


export result=$(grep '<name>'$DATASOURCE_PROPERTY'</name>' $DATASOURCE_FILE -A1| awk -F'<value>' '{print $2}' | awk -F'</value>'  '{print $1}'| awk '{$1=$1};1')
echo $result



