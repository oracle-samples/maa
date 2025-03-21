#!/bin/bash

## common_export_import_fmw.sh script version 1.0.
##
## Copyright (c) 2025 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script contains common fucntions for Oracle Data Pump export and import scrips for Oracle FMW


check_connection () {
schema=$1
tns_alias=$2
while true; do
        read -s -p "Provide the schema password for $schema: " pass
        if [ "$schema" == "SYS" ]; then
                export sys_pass=$pass
                echo
                oracledate=`sqlplus -s $schema/""${pass}""@${tns_alias} as sysdba <<-EOF
set echo off feedback off timing off pause off heading off verify off
whenever oserror exit failure
whenever sqlerror exit failure
select sysdate from dual;
 exit
EOF
`
        sqlerr=$?
        else
                export schema_pass=$pass
                echo
                oracledate=`sqlplus -s $schema/""${pass}""@${tns_alias} <<-EOF
set echo off feedback off timing off pause off heading off verify off
whenever oserror exit failure
whenever sqlerror exit failure
select sysdate from dual;
 exit
EOF
`
        sqlerr=$?
        fi
        if [ $sqlerr -ne 0 ]; then
                echo "Unable to connect to Oracle with this password for $schema. Try again!"
        else
                echo "Succesfully connected to DB as $schema."
                break
        fi
done
echo
}
waiting (){

chars="/-\|"

while :; do
  for (( i=0; i<${#chars}; i++ )); do
    sleep 0.5
    echo -en "This may take some time ${chars:$i:1}" "\r"
  done
done


}

