#!/bin/bash

## config_replica.sh script version 2.0
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


#config_replica.sh
### This script should be executed in the WLS Administration Node (either primary or standby).
### This script checks the current role of the database to determine if it is running in primary or standby site.
### When it runs in PRIMARY site: 
###	it copies the domain config from primary domain to local assistance folder (DBFS or FSS), 
##	and then to the secondary site assistance folder (via FSS/rsync or DBFS/DG replica).
### When it runs in STANDBY site: 
###	it copies the domain config from the secondary assistance folder (DBFS or FSS) to the secondary domain, skipping the appropiate folders
###
### This script depends on the appropriate execution of the fmw_primary and fmw_standy DR setup scripts 
### (or alternatively, the appropiate execution of the DRS tool).
###
### Since it is expected to be scheduled in cron, all variables need to be customized in the script itself (i.e. not passed as arguments)
### Usage:
###	The following variables (below) need to be edited/added in the script itself before executing the script
###	DR_METHOD
###		The DR Method used. It should be set to:
###		- DBFS:		When using DBFS method. 
###				The domain config replication to secondary site is done via Data Guard replica using a DBFS mount as assistance 
###				filesystem.
###		- RSYNC:	When using FSS with rsync method. 
###				The domain config replication to the secondary site will be done via rsync, using a FSS mount as assisntance 
###				filesystem.
###
###	LOCAL_CDB_CONNECT_STRING
###		The connect string of the local database, in the format <scan_address>:<port>:<CDB_servicename>. The script uses this
###		string to get the currentl role.
###		Provide the service of the CDB in this connect string, not the service of the PDB. 
###		The CDB service is normally the <DB_UNQNAME>.<db_domain_name>
###		Example: mydb-scan.dbsubnet.vcndomain.oraclevcn.com:1521/ORCL_phx2zb.dbsubnet.vcndomain.oraclevcn.com
###
###	LOCAL_STANDBY_CDB_CONNECT_STRING
###		[OPTIONAL PARAMETER]
###		Provide this ONLY when your database has a local standby database in the sameregion, in addition to the remote standby database.
###		If your database does not have any local standby in this region, leave this variable empty.
###		If your database has a local standby, this variable must be the connect string of the local standby database (using the CDB service)
###		Example: mydblocalstby-scan.dbsubnet.vcndomain.oraclevcn.com:1521/ORCL_STBY.dbsubnet.vcndomain.oraclevcn.com
###
###	ENCRYPTED_SYS_USER_PASSWORD
###		This is the WLS ENCRYPTED password of the SYS database user.
###		To encrypt the password use the script fmw_enc_pwd.sh script (./fmw_enc_pwd.sh UNENCRIPTED_PASSWORD) 
###		The obtained string is the one to be used bellow for the ENCRYPTED_SYS_USER_PASSWORD variable
###		Example: "{AES256}/J5c+WjFrgQjb3+7/AgBkUzhqAJlh4BW4iGmmPEdsp/8MS//CZkpX1bc/PLqLS31"
###	
###	REMOTE_ADMIN_NODE_IP
###		[ONLY WHEN DR_METHOD IS RSYNC]. 
###		Peer remote Weblogic Administration server node's IP. This is the IP of the node hosting the WLS Administration Server
###		in the peer site. It needs to be reachable from the local node. It is recommended to connect to the remote private ip of the node
###		via Dynamic Routing Gateway.
###		Example: 10.2.1.1
###
###	REMOTE_KEYFILE
###		[ONLY WHEN DR_METHOD IS RSYNC]
###		The private ssh keyfile to connect to remote Weblogic Administration server node.
###		Example: /home/oracle/my_keys/KeyWithoutPassPhraseSOAMAA.priv
###
###	FSS_MOUNT
###		[ONLY WHEN DR_METHOD IS RSYNC]
###		This is the path to the mount point where the OCI File Storage file system is mounted. 
###		This OCI File Storage file system will be used to stage the WLS domain configuration.
###		Example:  /u01/share


###############################################################################################################
################# BEGIN OF CUSTOMIZED PARAMATERS SECTION ######################################################
###############################################################################################################
DR_METHOD=RSYNC
LOCAL_CDB_CONNECT_STRING=drdbrac8a-scan.dbsubnet.vcnlon160.oraclevcn.com:1521/ORCL8_LON.dbsubnet.vcnlon160.oraclevcn.com
LOCAL_STANDBY_CDB_CONNECT_STRING=
ENCRYPTED_SYS_USER_PASSWORD="{AES256}18aFY7QOoGi9gWmBX3Fqm2VizvENr52bqF58qUliuB/Mo0zjx2/CWJYzSlCJgMPo"
# ONLY when using RSYNC METHOD:
REMOTE_ADMIN_NODE_IP=10.4.160.105
REMOTE_KEYFILE=/u01/install/ssh_keys/KeyWithoutPassPhraseSOAMAA.priv
FSS_MOUNT=/u01/share


###############################################################################################################
################## END OF CUSTOMIZED PARAMATERS SECTION #######################################################
###############################################################################################################



#export verbose=true
export date_label=$(date '+%Y-%m-%d-%H_%M_%S')
export exec_path=$(dirname "$0")
export log_path=${exec_path}/log
mkdir -p ${log_path}
export log_file=${log_path}/config_replica_log_${date_label}.log


echo "" | tee -a  $log_file
echo "SCRIPT TO COPY WLS CONFIGURATION IN DR" | tee -a  $log_file
echo "This script depends on the appropriate execution of the fmw dr setup scripts in_primary and standby," | tee -a  $log_file
echo "or alternatively, the appropiate execution of the DRS tool." | tee -a  $log_file
echo "" | tee -a  $log_file
echo "" | tee -a  $log_file
echo "CUSTOM SETTINGS" | tee -a  $log_file
echo " DR_METHOD = ${DR_METHOD}" | tee -a  $log_file
echo " LOCAL_CDB_CONNECT_STRING = ${LOCAL_CDB_CONNECT_STRING}" | tee -a  $log_file
if [[ ! -z "${LOCAL_STANDBY_CDB_CONNECT_STRING}" ]];then
	echo " LOCAL_STANDBY_CDB_CONNECT_STRING	= ${LOCAL_STANDBY_CDB_CONNECT_STRING}" | tee -a  $log_file
fi
echo " REMOTE_ADMIN_NODE_IP	(only for RSYNC DR METHOD) = ${REMOTE_ADMIN_NODE_IP}" | tee -a  $log_file
echo " REMOTE_KEYFILE		(only for RSYNC DR METHOD) = ${REMOTE_KEYFILE}" | tee -a  $log_file
echo " FSS_MOUNT		(only for RSYNC DR METHOD) = ${FSS_MOUNT}" | tee -a  $log_file



######################################################################################################################
# FUNCTIONS
######################################################################################################################

get_DR_method(){
	echo "" | tee -a  $log_file
        echo "GET DR TOPOLOGY METHOD" | tee -a  $log_file
	echo "Check whether DR topology is based on DBFS or remote RSYNC..." | tee -a  $log_file
	if  [[ $DR_METHOD = "RSYNC" ]] || [[ $DR_METHOD = "DBFS" ]]; then
		echo "This DR topology is based on.........." $DR_METHOD | tee -a  $log_file
	else
		echo "ERROR: DR topology unknown" | tee -a  $log_file
		exit 1
	fi
}

get_PAAS_type(){
	echo "" | tee -a  $log_file
	echo "GET PAAS TYPE" | tee -a  $log_file
	# Determining if WLSMP or SOAMP using the hostname naming (not valid for SOACS)
	hostnm=$(hostname)
	if [ -d /u01/app/oracle/suite ]; then
		export PAAS=SOAMP
	elif [[ $hostnm == *"-wls-"* ]]; then
		export PAAS=WLSMP
	else
		echo "Error. PAAS service unknown" | tee -a  $log_file
		exit 1
	fi

	echo "This PAAS service is ................." $PAAS | tee -a  $log_file
}

get_variables(){
	echo "" | tee -a  $log_file
	echo "GET AND CHECK VARIABLES" | tee -a  $log_file
	# COMMON VARIABLES
	export datasource_name=opss-datasource-jdbc.xml
	export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
	export tns_admin=$( grep tns_admin -A1 $datasource_file | grep value | awk -F '<value>' '{print $2}' | awk -F '</value>' '{print $1}')
	export sys_username=sys
	export sys_user_password=$(${exec_path}/fmw_dec_pwd.sh $ENCRYPTED_SYS_USER_PASSWORD)
	
	if [ -z "${DOMAIN_HOME}" ];then
		echo "\$DOMAIN_HOME is empty. This variable is predefined in the oracle user's .bashrc. " | tee -a  $log_file
		echo "Example: export DOMAIN_HOME=/u01/data/domains/my_domain" | tee -a  $log_file
		exit 1
	fi

        if [ -f "${datasource_file}" ]; then
                echo "The datasource ${datasource_name} exists" | tee -a  $log_file
        else
                echo "The datasource ${datasource_name} does not exist" | tee -a  $log_file
                echo "Provide an alternative datasource name" | tee -a  $log_file
                exit 1
        fi

	if [ -z "${tns_admin}" ];then
		echo "\$tns_admin property not set in the datasource. Cannot proceed" | tee -a  $log_file
		exit 1
	fi


	if [[ ${verbose} = "true" ]]; then
		echo "Variable values (common):" | tee -a  $log_file
		echo " datasource_name......................" ${datasource_name} | tee -a  $log_file
		echo " DOMAIN_HOME.........................." ${DOMAIN_HOME} | tee -a  $log_file
		echo " tns_admin for datasources............" ${tns_admin} | tee -a  $log_file
		echo " sys_username........................." ${sys_username} | tee -a  $log_file
	fi

	# VARIABLES FOR REMOTE RSYNC METHOD
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		export copy_folder=${FSS_MOUNT}/domain_config_copy
		if [[ ${verbose} = "true" ]]; then
			echo "Variable values (for RSYNC method):" | tee -a  $log_file
			echo " FSS_MOUNT............................" ${FSS_MOUNT} | tee -a  $log_file
			echo " copy_folder.........................." ${copy_folder} | tee -a  $log_file
			echo " REMOTE_ADMIN_NODE_IP................." ${REMOTE_ADMIN_NODE_IP} | tee -a  $log_file
			echo " REMOTE_KEYFILE......................." ${REMOTE_KEYFILE} | tee -a  $log_file
		fi

	# VARIABLES FOR DBFS METHOD
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		export dbfs_mount_script=${DOMAIN_HOME}/dbfs/dbfsMount.sh
		export ORACLE_HOME=$(cat $dbfs_mount_script | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
		export TNS_ADMIN=$(cat $dbfs_mount_script | grep "TNS_ADMIN=" | head -n 1 | awk -F "=" '{print $2}')
		export dbfs_mount=$(cat $dbfs_mount_script | grep "MOUNT_PATH=" | head -n 1 | awk -F "=" '{print $2}')
		export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
		export PATH=$PATH:$ORACLE_HOME/bin
		if [[ ${PAAS} = "SOAMP" ]]; then
			export copy_folder=$dbfs_mount/share
		elif [[ ${PAAS} = "WLSMP" ]]; then
			export copy_folder=$dbfs_mount/dbfsdir
		fi
		if [[ ${verbose} = "true" ]]; then
			echo "Variable values (for DBFS method):" | tee -a  $log_file
			echo " dbfs_mount_script...................." ${dbfs_mount_script} | tee -a  $log_file
			echo " ORACLE_HOME.........................." ${ORACLE_HOME} | tee -a  $log_file
			echo " TNS_ADMIN for DBFS..................." ${TNS_ADMIN} | tee -a  $log_file
			echo " dbfs_mount..........................." ${dbfs_mount} | tee -a  $log_file
			echo " copy_folder.........................." ${copy_folder} | tee -a  $log_file
		fi
	else
		echo "Error. DR topology unknown" | tee -a  $log_file
		exit 1
	fi		
}

get_localdb_role(){
	echo "" | tee -a  $log_file
	echo "GET LOCAL DB ROLE" | tee -a  $log_file
	# To support other methods: WLST, SQLPLUS,OCI  API..For now, WLST
	export role_check_method=WLST
	if  [[ ${role_check_method} = "WLST" ]]; then
		get_localdb_role_WLST
	elif [[ ${role_check_method} = "SQLPLUS" ]]; then
		get_localdb_role_SQLPLUS
	elif [[ ${role_check_method} = "OCIAPI" ]]; then
		get_localdb_role_OCIAPI
	else
		echo "Unknown method to get the local role" | tee -a  $log_file
		exit 1
	fi

	if  [[ ${db_role} = *PRIMARY* ]] || [[ ${db_role} = *STANDBY* ]]; then
		echo "Local role is ${db_role}. " | tee -a  $log_file
	else
		echo "Error. Unable to get the local role" | tee -a  $log_file
		exit 1
	fi
}

get_localdb_role_WLST(){
	export jdbc_url="jdbc:oracle:thin:@"$LOCAL_CDB_CONNECT_STRING
	export username="sys"
	export db_role=$(${exec_path}/fmw_get_dbrole_wlst.sh ${username} ${sys_user_password} ${jdbc_url} )
	echo "The role of the database is: ${db_role}" | tee -a  $log_file

	# To support LOCAL DG, check also the role of the local DG
	# Because in case of a local switchover, the role site is still primary
	if [[ ! -z ${LOCAL_STANDBY_CDB_CONNECT_STRING} ]]; then
        echo "Checking the role of the additional local database..." | tee -a  $log_file
        export local_stby_jdbc_url="jdbc:oracle:thin:@"${LOCAL_STANDBY_CDB_CONNECT_STRING}
        export local_stby_db_role=$(${exec_path}/fmw_get_dbrole_wlst.sh ${username} ${sys_user_password} ${local_stby_jdbc_url} )
        echo "The role of the local DG database is: " ${local_stby_db_role} | tee -a  $log_file
        if  [[ ${db_role} = *PRIMARY* ]] || [[ ${local_stby_db_role} = *PRIMARY* ]]; then
			db_role="PRIMARY"
			echo "The role of this SITE is $db_role" | tee -a  $log_file
		fi
	fi
}

get_localdb_role_SQLPLUS(){
	#TBD
	echo "" | tee -a  $log_file
}

get_localdb_role_OCIAPI(){
	#TBD
	echo "" | tee -a  $log_file
}

checks_in_primary(){
	echo "" | tee -a  $log_file
	echo "CHECKS IN PRIMARY" | tee -a  $log_file
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
	    checks_in_primary_RSYNC
	elif [[ ${DR_METHOD} = "DBFS" ]];then
	    checks_in_primary_DBFS
	else
	    echo "Error. DR topology unknown" | tee -a  $log_file
	    exit 1
	fi
}

checks_in_primary_RSYNC(){
	echo "Checking ssh connectivity to remote Weblogic Administration server node..." | tee -a  $log_file
	export result=$(ssh -o ConnectTimeout=100 -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
	if [ $result == "OK" ];then
	    echo "Connectivity to ${REMOTE_ADMIN_NODE_IP} is OK" | tee -a  $log_file
	    export remote_admin_hostname=$(ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} 'hostname --fqdn')
	    echo "remote_admin_hostname......" ${remote_admin_hostname} | tee -a  $log_file
	    echo ""
	else
	    echo "Error: Failed to connect to ${REMOTE_ADMIN_NODE_IP}" | tee -a  $log_file
	    exit 1
	fi
	
	echo "Checking local FSS ${FSS_MOUNT} folder readiness..." | tee -a  $log_file
	if mountpoint -q ${FSS_MOUNT}; then
	    echo "Mount at ${FSS_MOUNT} is ready!" | tee -a  $log_file
	    echo "Will use ${copy_folder} to stage the domain configuration in local site." | tee -a  $log_file
	    echo ""
	    mkdir -p ${copy_folder}
    else
        echo "Error: local FSS mount not available at ${FSS_MOUNT}" | tee -a  $log_file
        exit 1
    fi

    echo "Checking remote FSS mount folder readiness..." | tee -a  $log_file
    if ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "mountpoint -q ${FSS_MOUNT}";then
        echo "Remote mount at ${REMOTE_ADMIN_NODE_IP}:${FSS_MOUNT} is ready!" | tee -a  $log_file
		echo "Will use ${REMOTE_ADMIN_NODE_IP}:${copy_folder} to stage the domain configuration in remote site." | tee -a  $log_file
		ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "sudo su - oracle -c \"mkdir -p  ${copy_folder}\" "
    else
        echo "Error: remote FSS mount not ready at ${REMOTE_ADMIN_NODE_IP}:${FSS_MOUNT}." | tee -a  $log_file
        exit 1
    fi
}

checks_in_primary_DBFS(){
	echo "Checking DBFS mount point..." | tee -a  $log_file
	if mountpoint -q $dbfs_mount; then
		echo "Mount at $dbfs_mount is ready!" | tee -a  $log_file
	else
		echo "DBFS Mount point not available. Will try to mount again..." | tee -a  $log_file
		${dbfs_mount_script}
		sleep 10
		if mountpoint -q $dbfs_mount; then
			echo "Mount at $dbfs_mount is ready!" | tee -a  $log_file
		else
			echo "Error: DBFS Mount point not available even after another try to mount. Check your DBFS set up." | tee -a  $log_file
                	exit 1
		fi
	fi
}

checks_in_secondary(){
    echo "" | tee -a  $log_file
    echo "CHECKS IN SECONDARY" | tee -a  $log_file
    if  [[ ${DR_METHOD} = "RSYNC" ]]; then
        checks_in_secondary_RSYNC
    elif [[ ${DR_METHOD} = "DBFS" ]];then
        checks_in_secondary_DBFS
    else
        echo "Error. DR topology unknown" | tee -a  $log_file
        exit 1
    fi
}


checks_in_secondary_RSYNC(){
    echo "Checking local FSS mount folder readiness..." | tee -a  $log_file
    echo "The FSS is expected to be mounted in ${FSS_MOUNT}" | tee -a  $log_file
    echo "The folder for the copy of the domain is expected to be ${copy_folder}" | tee -a  $log_file

    if mountpoint -q ${FSS_MOUNT}; then
        echo "Mount at ${FSS_MOUNT} is ready!" | tee -a  $log_file
		if [ -d "${copy_folder}" ];then
			echo "Local folder ${copy_folder} exists." | tee -a  $log_file
		else
			echo "Error: local folder ${copy_folder} not available" | tee -a  $log_file
		exit 1
		fi
    else
        echo "Error: local FSS mount not available at ${FSS_MOUNT}" | tee -a  $log_file
        exit 1
    fi
}

checks_in_secondary_DBFS(){
	echo "Checking if standby is in physical or snapshot standby..." | tee -a  $log_file
	if [[ $db_role = *"PHYSICAL STANDBY"* ]]; then
		echo "Standby DB is in physical standby status" | tee -a  $log_file
		echo "Will convert to snapshot standby in order to mount DBFS" | tee -a  $log_file
		create_temp_tnsnames
		convert_standby "snapshot standby"
	else
		echo "Standby DB is already in snapshot standby status" | tee -a  $log_file
	fi
	# Check dbfs mount and retry if needed
	check_and_retry_dbfs_mount
}

create_temp_tnsnames(){
	export primary_cdb_unqname=$(
	echo "set feed off
	set pages 0
	alter session set NLS_COMP=ANSI;
	alter session set NLS_SORT=BINARY_CI;
	select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DEST_ROLE like '%PRIMARY%';
	exit
	"  | sqlplus -s $sys_username/$sys_user_password@${LOCAL_CDB_CONNECT_STRING} "as sysdba"
	)

	if [[ ${primary_cdb_unqname} = "" ]] ; then
		echo "Error: Cannot determine primary_cdb_unqname"
		exit 1
	fi

	export local_cdb_unqname=$(
	echo "set feed off
	set pages 0
	alter session set NLS_COMP=ANSI;
	alter session set NLS_SORT=BINARY_CI;
	select DB_UNIQUE_NAME from V\$DATABASE;
	exit
	"  | sqlplus -s $sys_username/$sys_user_password@${LOCAL_CDB_CONNECT_STRING} "as sysdba"
	)
	if [[ ${local_cdb_unqname} = "" ]] ; then
		echo "Error: Cannot determine local_cdb_unqname"
		exit 1
	fi

	export primary_cdb_tns_string=$(
	echo "set feed off
	set pages 0
	set lines 10000
	SELECT DBMS_TNS.RESOLVE_TNSNAME ('"${primary_cdb_unqname}"') from dual;
	exit
	"  | sqlplus -s $sys_username/${sys_user_password}@${LOCAL_CDB_CONNECT_STRING} "as sysdba"
 	)
	if [[ ${primary_cdb_tns_string} = "" ]] ; then
		echo "Error: Cannot determine primary_cdb_tns_string"
		exit 1
	fi
	# Removing additional CID entry at the end of the string
	primary_cdb_tns_string=$(echo $primary_cdb_tns_string  | awk -F '\\(CID=' '{print $1}')
	# Adding required closing parenthesis
	primary_cdb_tns_string=${primary_cdb_tns_string}"))"
	
	export local_cdb_tns_string=$(
	echo "set feed off
	set pages 0
	set lines 10000
	SELECT DBMS_TNS.RESOLVE_TNSNAME ('"${local_cdb_unqname}"') from dual;
	exit
	"  | sqlplus -s $sys_username/${sys_user_password}@${LOCAL_CDB_CONNECT_STRING} "as sysdba"
	)
	if [[ ${local_cdb_tns_string} = "" ]] ; then
		echo "Error: Cannot determine local_cdb_tns_string"
		exit 1
	fi
	# Removing additional CID entry at the end of the string
	local_cdb_tns_string=$(echo $local_cdb_tns_string  | awk -F '\\(CID=' '{print $1}')
	# Adding required closing parenthesis
	local_cdb_tns_string=${local_cdb_tns_string}"))"

	if [[ ${verbose} = "true" ]]; then
		echo "Primary CDB UNIQUE NAME..........." $primary_cdb_unqname
		echo "Local CDB UNIQUE NAME (standby)..." $local_cdb_unqname		
		echo "TNS string to primary CDB........." ${primary_cdb_tns_string}
		echo "TNS string to local CDB (standby)." ${local_cdb_tns_string}
	fi

	# Creating temporal tnsnames.ora
	tmp_tns_admin=/tmp/tmp_tns_admin_${date_label}
	mkdir -p ${tmp_tns_admin}
	cat > ${tmp_tns_admin}/tnsnames.ora <<EOF
${primary_cdb_unqname} = ${primary_cdb_tns_string}
${local_cdb_unqname}= ${local_cdb_tns_string}
EOF

}

convert_standby(){
	standby_req_status=$1
	echo "Converting standby db to ${standby_req_status}..." | tee -a  $log_file
	export TNS_ADMIN=${tmp_tns_admin}
	export conversion_result=$(
	dgmgrl ${sys_username}/\'${sys_user_password}\'@${primary_cdb_unqname} "convert database '${local_cdb_unqname}' to ${standby_req_status}"
	)
	if [[ ${verbose} = "true" ]]; then
		echo $conversion_result | tee -a  $log_file
	fi

	if [[ $conversion_result = *successful* ]]
        then
        	echo "Standby database converted to $standby_req_status !" | tee -a  $log_file
	else
        	echo "Error. Database conversion FAILED. Check Data Guard status." | tee -a  $log_file
        	exit 1
	fi
}

check_and_retry_dbfs_mount(){
	echo "Checking DBFS mount point..." | tee -a  $log_file
	if mountpoint -q $dbfs_mount; then
        echo "Mount at $dbfs_mount is ready!" | tee -a  $log_file
		return 1
	else
        echo "DBFS Mount point not available. Will try to mount again..." | tee -a  $log_file
	    ${dbfs_mount_script}
        sleep 10
        if mountpoint -q $dbfs_mount; then
			echo "Mount at $dbfs_mount is ready." | tee -a  $log_file
		else
            echo "Error: DBFS Mount point not available even after another try to mount. Check your DBFS set up." | tee -a  $log_file
        	exit 1
	    fi
	fi
}


sync_in_primary(){
    echo "" | tee -a  $log_file
    echo "SYNC IN PRIMARY" | tee -a  $log_file
    if  [[ ${DR_METHOD} = "RSYNC" ]]; then
        ${exec_path}/fmw_sync_in_primary.sh ${DR_METHOD} ${DOMAIN_HOME} ${copy_folder} ${tns_admin} ${REMOTE_ADMIN_NODE_IP} ${REMOTE_KEYFILE} | tee -a  $log_file
    elif [[ ${DR_METHOD} = "DBFS" ]];then
        ${exec_path}/fmw_sync_in_primary.sh ${DR_METHOD} ${DOMAIN_HOME} ${copy_folder} ${tns_admin} | tee -a  $log_file
    else
        echo "Error. DR topology unknown" | tee -a  $log_file
        exit 1
    fi
}

sync_in_secondary(){
    echo "" | tee -a  $log_file
    echo "SYNC IN SECONDARY" | tee -a  $log_file
    ${exec_path}/fmw_sync_in_standby.sh ${DR_METHOD} ${DOMAIN_HOME} ${copy_folder} | tee -a  $log_file
}


post_sync_in_secondary(){
    echo "" | tee -a  $log_file
    echo "POST SYNC TASKS IN SECONDARY" | tee -a  $log_file
    if  [[ ${DR_METHOD} = "RSYNC" ]]; then
        post_sync_in_secondary_RSYNC
    elif [[ ${DR_METHOD} = "DBFS" ]];then
        post_sync_in_secondary_DBFS
    else
        echo "Error. DR topology unknown" | tee -a  $log_file
        exit 1
    fi
}

post_sync_in_secondary_RSYNC(){
	echo "nothing to do" | tee -a  $log_file
	# nothing to do
}

post_sync_in_secondary_DBFS(){
	# db_role has the value of the initial status of the standby database
	# if it was physical standby, we need to convert to physical standby again
	if [[ $db_role = *"PHYSICAL STANDBY"* ]]; then
		echo "Standby database was originally in PHYSICAL STANDBY mode" | tee -a  $log_file
		echo "Converting it to PHYSICAL STANDBY again..." | tee -a  $log_file
		convert_standby "physical standby"
	elif [[ $db_role = *"SNAPSHOT STANDBY"* ]]; then
		echo "Standby database was originally in SNAPSHOT STANDBY mode" | tee -a  $log_file
		echo "Hence, NOT converting it to physical standby" | tee -a  $log_file
	fi

}


######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################


######################################################################################################################
# MAIN
######################################################################################################################
get_DR_method
get_PAAS_type
get_variables
get_localdb_role
if [[ $db_role = *PRIMARY* ]]; then
	echo "This site has PRIMARY role. " | tee -a  $log_file
	echo "The script will copy data from domain directory to assistance folder (dbfs/FSS)." | tee -a  $log_file
	checks_in_primary
	sync_in_primary	
elif [[ $db_role = *"PHYSICAL STANDBY"* ]] || [[ $db_role = *"SNAPSHOT STANDBY"* ]]; then
	echo "This site has STANDBY role. " | tee -a  $log_file
	echo "The script will copy data from assistance folder (dbfs/FSS) to local domain directory." | tee -a  $log_file
	checks_in_secondary
	sync_in_secondary
	post_sync_in_secondary
else
  	echo "Unable to identify the DB's role." | tee -a  $log_file
	echo $(date '+%d-%m-%Y-%H-%M-%S') > ${DOMAIN_HOME}/last_failed_update.log
fi

echo "FINISHED" | tee -a  $log_file

######################################################################################################################
# END OF MAIN
######################################################################################################################

