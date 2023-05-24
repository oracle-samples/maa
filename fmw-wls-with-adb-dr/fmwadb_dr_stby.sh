#!/bin/bash

## fmwadb_dr_stby.sh script version 2.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script prepares a secondary site for the DR setup
### This script should be executed in the SECONDARY Weblogic Administration server node. BEFORE executing this script
### the fmwadb_dr_rsync_only_prim.sh script should have been executed in the primary system so that a copy of the primary domain exists in the local
##  FSS mount
### Usage:
###
###      ./fmwadb_dr_stby.sh [WALLET_DIR] [WALLET_PASSWORD] [FSS_MOUNT]
### Where:
###	WALLET_DIR:
###					This is the directory for an unzipped ADB wallet.
###					This directory should contain at least a tnsnames.ora, keystore.jks and truststore.jks files. 
###	WALLET_PASSWORD:		
###					This is the password provided when the wallet was downloaded from the ADB OCI UI.
###					If the wallet is the initial one created by WLS/SOA/FMW during provisioning it can be obtained
###					with the following commands:
###					SOA	python /opt/scripts/atp_db_util.py generate-atp-wallet-password
###					WLS	python3 /opt/scripts/atp_db_util.py generate-atp-wallet-password
###					
###	FSS_MOUNT:
###					This is the OCI File Storage Mounted directory that will be used to stage the WLS domain configuration


export wls_domain_name=$(echo ${DOMAIN_HOME} |awk -F '/u01/data/domains/' '{print $2}')
export datasource_name=opss-datasource-jdbc.xml
export date_label=$(date +%H_%M_%S-%d-%m-%y)
export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
export remote_datasource_file="${copy_folder}/$wls_domain_name/config/jdbc/${datasource_name}"
export exec_path=$(dirname "$0")

#For internal use, we allow speficying a backup option
if [[ $# -eq 3 ]]; then
	echo "Backup option selected"
	export backup=true
elif [[ $# -eq 4 ]]; then
	if [ "$4" == "backup" ]; then
		echo "Backup option selected"
		export backup="true"
	elif [ "$4" == "nobackup" ]; then
		echo "No-Backup option selected"
		export backup="false"
	else
		echo "ERROR: Incorrect backup option specified, got $4. Expected either backup or nobackup"
		exit 1
	fi
	
else
        echo ""
        echo "ERROR: Incorrect number of parameters used. Expected 3, got $#"
        echo "Usage :"
        echo "    $0 WALLET_DIR WALLET_PASSWORD FSS _MOUNT"
        echo "Example:  "
        echo "    $0  '/tmp/adbw' 'my_pwdXXXX' /u01/soacs/dbfs/share"
        echo ""
        exit 1
fi

create_domain_backup() {
        echo "Backing up current domain..."
        cp -R ${DOMAIN_HOME}/ ${DOMAIN_HOME}_backup_$date_label
        echo "Backup created at ${DOMAIN_HOME}/ ${DOMAIN_HOME}_backup_$date_label"

}

sync_in_secondary_RSYNC(){
        echo "Rsyncing from FSS  mount to domain dir..."
        rm  -rf ${DOMAIN_HOME}/servers/*
        hostnm=$(hostname)
        if [[ $hostnm == *"-0"* ]]; then
                # if this is Weblogic Administration server node, copy all except tmp
                # (not valid for SOACS), because admin is wls-1 in that case
                echo " Syncing the Weblogic Administration server node..."
                sleep 10
                rsync -avz  --exclude 'tmp' ${copy_folder}/$wls_domain_name/ ${DOMAIN_HOME}/ >> $rsync_log_file
        else
                echo " Syncing a managed server node..."
                sleep 10
                # if this is not the Weblogic Administration server node, exclude copy servers folder also
                rsync -avz  --exclude 'tmp' --exclude '/servers/' ${copy_folder}/$wls_domain_name/ ${DOMAIN_HOME}/  >> $rsync_log_file_ms
                fi
        echo $(date '+%d-%m-%Y-%H-%M-%S') > ${DOMAIN_HOME}/last_secondary_update.log
        echo "Rsync complete!"

}

fmwadb_switch_db_conn() {
	echo "Switching config to ${WALLET_DIR}"
	$exec_path/fmwadb_switch_db_conn.sh  ${WALLET_DIR} ${WALLET_PASSWORD}
}

export WALLET_DIR=$1
export WALLET_PASSWORD=$2
export FSS_MOUNT=$3
export copy_folder=${FSS_MOUNT}/domain_config_copy
export rsync_log_file=${copy_folder}/last_sec_update_${date_label}.log
export rsync_log_file_ms=${copy_folder}/last_sec_update_ms_${date_label}.log

if [[ $backup == "true" ]]; then
	create_domain_backup
fi
sync_in_secondary_RSYNC
fmwadb_switch_db_conn
