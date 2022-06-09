#!/bin/bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script should be executed on the WLS Admin Server node at standby site

##### The following variables need to be passed as parameters to the script in this exact order:

##### A_DB_IP                   Public IP of the primary database node (it can be scan address for RAC cases)
##### A_DB_PORT                 The port of primary database's TNS Listener
##### A_PDB_SERVICE             The PDB service name of the primary database
##### WLS_DOMAIN_NAME           The Weblogic Domain used by the SOACS service
##### SYS_DB_USERNAME           The SYSDBA user name at the secondary/standby database
##### SYS_DB_PASSWORD           The SYSDBA user password at the secondary/standby database

###
### Example:
###        fmw_standby_check_db_connectivity.sh  '129.146.117.58'  '1521'  'soa7pdb.sub10171336420.soacsdrvcn.oraclevcn.com' \
###                             'soacsdr7_domain'  'sys'  'my_password'
###

print_usage()
{
    echo "Usage: "
    echo "  $0  A_DB_IP  A_DB_PORT  A_PDB_SERVICE  WLS_DOMAIN_NAME  SYS_DB_USERNAME  SYS_DB_PASSWORD"
    echo "  where:"
    echo "      A_DB_IP                       IP of the primary site database node (it can be scan address for RAC cases)"
    echo "      A_DB_PORT                     The port of primary site database's TNS Listener"
    echo "      A_PDB_SERVICE                 The primary site database PDB service"
    echo "      WLS_DOMAIN_NAME               The Weblogic Domain name used by the SOACS service"
    echo "      SYS_DB_USERNAME               The SYS DBA username for the secondary/standby database"
    echo "      SYS_DB_PASSWORD               The SYS DBA user password for the secondary/standby database"
    echo ""
    echo "Example: $0 '129.146.117.58'  '1521'  'soa7pdb.sub10171336420.soacsdrvcn.oraclevcn.com'  'soacsdr7_domain'  'sys'  'welcome1'"
}

if [[ $# -ne 6 ]]; then
    echo
    echo "ERROR: Incorrect number of input variables passed to $0"
    echo
    print_usage
    echo
    exit -1
fi

export A_DB_IP=$1
export A_DB_PORT=$2
export A_PDB_SERVICE=$3
export WLS_DOMAIN_NAME=$4
export SYS_DB_USERNAME=$5
export SYS_DB_PASSWORD=$6

echo "Input parameters passed to script: "
echo " A_DB_IP = $1"
echo " A_DB_PORT = $2"
echo " A_PDB_SERVICE = $3"
echo " WLS_DOMAIN_NAME = $4"
echo " SYS_DB_USERNAME = $5"
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
export TNS_ADMIN=${WLS_BASE}/${WLS_DOMAIN_NAME}/dbfs

echo "******************************** Checking connectivity to Primary DB *******************************"
echo

export db_primary_type=$(
echo "set feed off
set pages 0
select database_role from v\$database;
exit
"  | sqlplus -s ${SYS_DB_USERNAME}/${SYS_DB_PASSWORD}@${A_DB_IP}:${A_DB_PORT}/${A_PDB_SERVICE} "as sysdba"
)
if  [[ ${db_primary_type} = *PRIMARY* ]]; then
   echo "Sys password is valid and DB is in correct status ($db_primary_type). Proceeding..."
   export db_secondary_type=$(
   echo "set feed off
   set pages 0
   select DEST_ROLE from V\$DATAGUARD_CONFIG where DEST_ROLE like '%STANDBY%';
   exit
   "  | sqlplus -s ${SYS_DB_USERNAME}/${SYS_DB_PASSWORD}@${A_DB_IP}:${A_DB_PORT}/${A_PDB_SERVICE} "as sysdba"
   )
   echo "Secondary DB status is " ${db_secondary_type}
   echo "SUCCESS: Database connectivity check passed"
   exit 0
else
    echo "ERROR: Database connectivity check FAILED";
    exit -1
fi
