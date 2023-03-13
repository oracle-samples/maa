#!/bin/bash

## fmw_get_connect_string.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

## This script returns  connect string that a WLS/SOA/FMW datasource is using
##
## Usage:
##        ./fmw_get_connect_string.sh DATASOURCE_FILE
##
## Where:
##	DATASOURCE_FILE 	The WLS jdbc datasource file (complete path)

### EXAMPLE: 
### ./fmw_get_connect_string.sh  /u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml 

if [[ $# -eq 1 ]]; then
	export DATASOURCE_FILE=$1
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 1, got $#"
	echo "Usage :"
	echo "    $0  DATASOURCE_FILE"
	echo "Example:  "
	echo "    $0  '/u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml'"
	echo ""
	exit 1
fi

export result=$(grep url ${DATASOURCE_FILE} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}' | awk '{$1=$1};1')
echo $result



