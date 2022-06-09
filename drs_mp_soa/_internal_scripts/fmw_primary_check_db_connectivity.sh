#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

###
### This script should be executed on the WLS Admin Server Node in the Primary site
###

##### The following variables need to be passed as parameters to the script in this exact order:
##### WLS_DOMAIN_NAME               The Weblogic Domain name used by the SOACS service
##### SYS_DB_USERNAME               The SYSDBA user name at the secondary/standby database
##### SYS_DB_PASSWORD               The SYSDBA user password at the secondary/standby database

###
### Example:
###         fmw_primary_check_db_connectivity.sh  'soacsdr7_domain'  'sys'  'my_password'
###

function print_usage()
{
    echo "Usage: "
    echo "  $0  WLS_DOMAIN_NAME  SYS_DB_USERNAME  SYS_DB_PASSWORD"
    echo "  where:"
    echo "      WLS_DOMAIN_NAME               The Weblogic Domain name used by the SOACS service"
    echo "      SYS_DB_USERNAME               The SYS DBA username for the secondary/standby database"
    echo "      SYS_DB_PASSWORD               The SYS DBA user password for the secondary/standby database"
    echo
    echo "Example: $0  'soacsdr7_domain'  'sys'  'welcome1'"
    echo
}


export WLS_DOMAIN_NAME=$1
export SYS_DB_USERNAME=$2
export SYS_DB_PASSWORD=$3

echo "Input parameters passed to script ${0}: "
echo " WLS_DOMAIN_NAME = $1"
echo " SYS_DB_USERNAME = $2"
echo " SYS_DB_PASSWORD = ********"


# Variables with fixed values
export MW_HOME='/u01/app/oracle/middleware'
export WLS_BASE='/u01/data/domains'

#The location of the script used to mount dbfs filesystems
export DBFS_MOUNT_SCRIPT=${DOMAIN_HOME}/dbfs/dbfsMount.sh
#Variables obtained from the dbfs mount script
#Because they are different in SOA CS and SOA MP
export ORACLE_HOME=$(cat $DBFS_MOUNT_SCRIPT | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')

export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:${LD_LIBRARY_PATH}
export PATH=$PATH:${ORACLE_HOME}/bin
export DATE=$(date +%H:%M:%S-%d-%m-%y)
export TNS_ADMIN=${WLS_BASE}/${WLS_DOMAIN_NAME}/dbfs/

export A_JDBC_URL=$(grep url ${WLS_BASE}/${WLS_DOMAIN_NAME}/config/jdbc/opss-datasource-jdbc.xml | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
echo "Primary Connect String................" $A_JDBC_URL



if [[ $# -ne 3 ]]; then
    echo
    echo "ERROR: Incorrect number of input variables passed to script \"${0}\""
    echo
    print_usage
    exit -1
fi

echo
echo "******************************** Checking connectivity to Primary DB *******************************"
echo

export db_type=$(
    echo "set feed off
    set pages 0
    select database_role from v\$database;
    exit
    "  | sqlplus -s ${SYS_DB_USERNAME}/${SYS_DB_PASSWORD}@${A_JDBC_URL} "as sysdba"
)

echo "DB TYPE query returned: "${db_type}

if  [[ ${db_type} = *PRIMARY* ]]; then
   echo "SUCCESS: Database connectivity check passed"
   exit 0
else
    echo "ERROR: Database connectivity check FAILED";
    exit -1
fi

