#!/bin/bash

## fmw_get_ds_property.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

## This script returns the value of a specific datasource property from a datasource
##
## Usage:
##         ./fmw_get_ds_property.sh DATASOURCE_FILE DATASOURCE_PROPERTY
##
## Where:
##	DATASOURCE_FILE 	The WLS jdbc datasource file (complete path)
##	DATASOURCE_PROPERTY	The property name in datasource file

## EXAMPLE:
## ./fmw_get_ds_property.sh  '/u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml' oracle.net.tns_admin

if [[ $# -eq 2 ]]; then
	export DATASOURCE_FILE=$1
	export DATASOURCE_PROPERTY=$2
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 2, got $#"
	echo "Usage :"
	echo "    $0  DATASOURCE_FILE DATASOURCE_PROPERTY"
	echo "Example:  "
	echo "    $0  '/u01/data/domains_my_domain/config/jdbc/opss-datasource-jdbc.xml' 'oracle.net.tns_admin'"
	echo ""
	exit 1
fi

export property_name_value=$(grep '<name>'$DATASOURCE_PROPERTY'</name>' $DATASOURCE_FILE -A1)

if [[ "$property_name_value" == *"encrypted-value-encrypted"* ]]; then
        export result=$(echo $property_name_value | awk -F'<encrypted-value-encrypted>' '{print $2}' | awk -F'</encrypted-value-encrypted>'  '{print $1}'| awk '{$1=$1};1')
else
        export result=$(echo $property_name_value | awk -F'<value>' '{print $2}' | awk -F'</value>'  '{print $1}'| awk '{$1=$1};1')
fi

echo $result



