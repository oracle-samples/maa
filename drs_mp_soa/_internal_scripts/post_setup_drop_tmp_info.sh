#!/bin/bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# This script runs in stby soa and connect to primary PDB
# to delete a temporary table created during DRS run
# Input parameters are:
# $1 username
# $2 password
# primary db ip
# primary db port
# primary pdb name
SYS_USERNAME=$1
SYS_USER_PASSWORD=$2
A_DB_IP=$3
A_PORT=$4
PDB_SERVICE_PRIMARY=$5

export DBFS_MOUNT_SCRIPT=${DOMAIN_HOME}/dbfs/dbfsMount.sh
export ORACLE_HOME=$(cat $DBFS_MOUNT_SCRIPT | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$PATH:$ORACLE_HOME/bin

echo "Dropping temporary table DBFS_INFO from db ..................................."
echo "
Drop table DBFS_INFO;
exit
"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@$A_DB_IP:$A_PORT/$PDB_SERVICE_PRIMARY "as sysdba" > /dev/null
echo "Temporary table DBFS_INFO dropped"


