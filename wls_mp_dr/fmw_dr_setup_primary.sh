#!/bin/bash

## fmw_dr_setup_primary.sh script version 202401
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script should be executed in the PRIMARY Weblogic Administration server node.
###
### This script can run in interactive as well as non-interactive mode.  In the interactive
### mode, the user simply runs the script using the script name and the script prompts for all
### required inputs.  In the non-interactive mode, these inputs must be provided as command
### line arguments to the script (See below for usage).
###
### Interactive usage:
###         fmw_dr_setup_primary.sh 	(NOTE: User will be prompted for all values)
###
### Non-interactive usage:
###         fmw_dr_setup_primary.sh DR_METHOD [SYS_USER_PASSWORD] [REMOTE_ADMIN_NODE_IP] [REMOTE_SSH_PRIV_KEYFILE] [FSS_MOUNT]
###
### Where:
###	DR_METHOD:			The DR Method used. It should be set to:
###					- DBFS:		When using DBFS method. 
###							The domain config replication to secondary site is done via Data Guard replica.
###					- RSYNC: 	When using FSS with rsync method. 
###							The domain config replication to the secondary site will be done via rsync.
###
###	SYS_USER_PASSWORD:		[ONLY WHEN DR_METHOD IS DBFS]
###					The primary database SYS user's password
###
###	REMOTE_ADMIN_NODE_IP:		[ONLY WHEN DR_METHOD IS RSYNC] 
###					This is the IP address of the secondary Weblogic Administration server node.
###					This IP needs to be reachable from this host. 
###					It is recommended to use Dynamic Routing Gateway to interconnect primary and secondary sites, 
###					hence you can provide the private IP.
###					Example: 10.1.2.1
###
###	REMOTE_SSH_PRIV_KEYFILE:	[ONLY WHEN DR_METHOD IS RSYNC] 
###					The complete path to the ssh private keyfile used to connect to secondary Weblogic Administration server node.
###					Example: /u01/install/myprivatekey.key
###
###     FSS_MOUNT:			[ONLY WHEN DR_METHOD IS RSYNC]
###					This is the path to the mount point where the OCI File Storage file system is mounted
###					This OCI File Storage file system will be used to stage the WLS domain configuration.
###					Example: /u01/share

# Check that this is running by oracle
if [ "$(whoami)" != "oracle" ]; then
	echo "Script must be run as user: oracle"
	exit 1
fi


######################################################################################################################
# INPUT PARAMETERS SECTION
######################################################################################################################

if [[ $# -ne 0 ]]; then
	export DR_METHOD=$1
	if  [[ $DR_METHOD = "DBFS" ]]; then
		if [[ $# -eq 2 ]]; then
			export SYS_USER_PASSWORD=$2
		else
			echo ""
			echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 2, got $#"
			echo "Usage for DR_METHOD=DBFS:"
			echo "      $0 DR_METHOD SYS_USER_PASSWORD "
			echo "Example: "
			echo "      $0 'DBFS' 'acme1234#'"
			echo ""
			exit 1
		fi

	elif [[ $DR_METHOD = "RSYNC" ]]; then
		if [[ $# -eq 4 ]]; then
			export REMOTE_ADMIN_NODE_IP=$2
 			export REMOTE_KEYFILE=$3
			export FSS_MOUNT=$4
		else
			echo ""
			echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 4, got $#"
			echo "Usage for DR_METHOD=RSYNC:"
			echo "    $0  DR_METHOD REMOTE_ADMIN_NODE_IP REMOTE_KEYFILE FSS_MOUNT"
			echo "Example:  "
			echo "    $0  'RSYNC' '10.1.2.43' '/u01/install/KeyWithoutPassPhraseSOAMAA.ppk' '/u01/share' "
			echo ""
			exit 1
		fi
	else
		echo ""
		echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $1"
		echo "Usage: "
		echo "	$0 DR_METHOD [SYS_USER_PASSWORD] [REMOTE_ADMIN_NODE_IP] [REMOTE_KEYFILE] [FSS_MOUNT] "
		echo ""
		exit 1
	fi
else
	echo
	echo "No parameters passed as argument.  User will be prompted for parameters"
	echo
	echo
	echo "Please enter values for each script input when prompted below:"
	echo

	# Get the DR_METHOD
	echo
	echo "(1) Enter the method that is going to be used for the DR setup"
	echo "    The DR Method should be set to:"
	echo "        - DBFS:  When using DBFS method. The domain config replication to secondary site is done via Data Guard replica."
	echo "        - RSYNC: When using FSS with rsync method. The domain config replication to the secondary site will be done via rsync."

	echo
	echo " Enter DR METHOD (DBFS or RSYNC): "

	read -r DR_METHOD

	if  [[ $DR_METHOD = "DBFS" ]]; then
		# Get the DB SYS password
		while true; do
			echo
			echo "(2) The primary database SYS user's password"
			echo
			echo " Enter the password: "
			read -r -s  PW_STRING1
			echo " Re-enter the password again: "
			read -r -s  PW_STRING2
			[ "$PW_STRING1" = "$PW_STRING2" ] && break
			echo "Passwords do not match. Please try again."
			echo
		done
	fi
		

	if  [[ $DR_METHOD = "RSYNC" ]]; then
		# Get the Remote WLS Administration server node IP
		echo
		echo "(2) Enter the IP address of the secondary Weblogic Administration server node."
		echo "    Note: this IP needs to be reachable from this host." 
		echo "	  Recommended to use DRG to interconnect primary and secondary sites, hence you can provide the private IP"
		echo
		echo " Enter secondary Weblogic Administration server node IP: "
		read -r REMOTE_ADMIN_NODE_IP

		# Get the ssh private keyfile for Weblogic Administration server node IP
		echo
		echo "(3) Enter the complete path to the ssh private keyfile used to connect to secondary Weblogic Administration server node."
		echo "    Example: /u01/install/myprivatekey.ppk"
		echo "    This is needed for the remote rsync commands"
		echo
		echo " Enter path to the private ssh keyfile: "

		read -r REMOTE_KEYFILE
		
		# Get the OCI FS file system mount point folder
		echo "(4) Enter the path to the mount point where the OCI File Storage file system is mounted:"
		echo "    Example: /u01/share "
		echo "    This is will be used as staging folder for copying the domain to secondary"
		echo
		echo " Enter path to the mount point: "
		read -r FSS_MOUNT
	fi
fi

######################################################################################################################
# END OF VARIABLES SECTION
######################################################################################################################

export verbose=true
export date_label=$(date '+%Y-%m-%d-%H_%M_%S')
export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check dependencies
if [[ ! -x "${exec_path}/fmw_get_ds_property.sh" ]]; then
	echo "Error. Script ${exec_path}/fmw_get_ds_property.sh not found or not executable"
	exit 1
fi

if [[ ! -x "${exec_path}/fmw_dec_pwd.sh" ]]; then
	echo "Error. Script ${exec_path}/fmw_dec_pwd.sh not found or not executable"
	exit 1
fi

if [[ ! -x "${exec_path}/fmw_sync_in_primary.sh" ]]; then
	echo "Error. Script ${exec_path}/fmw_sync_in_primary.sh not found or not executable"
	exit 1
fi



######################################################################################################################
# FUNCTIONS SECTION
######################################################################################################################

######################################################################################################################
############################### FUNCTIONS TO GET VARIABLES ###########################################################
######################################################################################################################

get_DR_method(){
	echo ""
	echo "GET DR TOPOLOGY METHOD"
	echo "Check whether DR topology is based on DBFS or remote RSYNC..."
	if  [[ $DR_METHOD = "RSYNC" ]] || [[ $DR_METHOD = "DBFS" ]]; then
		echo "This DR topology is based on.........." $DR_METHOD
	else
		echo "ERROR: DR topology unknown"
	exit 1
	fi
}

get_PAAS_type(){
    echo ""
    echo "GET PAAS TYPE"
    # Determining if WLSMP or SOAMP
    config_file=$DOMAIN_HOME/config/config.xml
    topology_soa=$(grep "soa-infra" $config_file | wc -l)
    topology_mft=$(grep "mft-app"  $config_file | wc -l)
    if [[ $topology_soa != 0 || $topology_mft != 0 ]];then
        export PAAS=SOAMP
    else
        export PAAS=WLSMP
    fi
    echo "This PAAS service is ................" $PAAS
}


get_variables(){
	echo ""
	echo "GET AND CHECK VARIABLES"
	# COMMON VARIABLES
	if [ -z "${DOMAIN_HOME}" ];then
		echo "\$DOMAIN_HOME is empty. This variable is predefined in the oracle user's .bashrc."
		echo "Example: export DOMAIN_HOME=/u01/data/domains/my_domain"
		exit 1
	fi

	if [[ ${verbose} = "true" ]]; then
		echo "Variable values (common):"
		echo " DOMAIN_HOME.........................." ${DOMAIN_HOME}
	fi

	# OTHER VARIABLES THAT DEPEND ON THE METHOD
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		get_variables_in_primary_RSYNC
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		get_variables_in_primary_DBFS
	else
		echo "Error. DR topology unknown"
		exit 1
	fi
}

get_variables_in_primary_RSYNC(){
	export copy_folder=${FSS_MOUNT}/domain_config_copy
	if [[ ${verbose} = "true" ]]; then
		echo "Variable values (for RSYNC method):"
		echo " FSS_MOUNT............................" ${FSS_MOUNT}
		echo " copy_folder.........................." ${copy_folder}
		echo " REMOTE_ADMIN_NODE_IP................." ${REMOTE_ADMIN_NODE_IP}
		echo " REMOTE_KEYFILE......................." ${REMOTE_KEYFILE}
	fi
}

get_variables_in_primary_DBFS(){
	export sys_username=sys
	# only used for SOAMP
	export datasource_name=opss-datasource-jdbc.xml
	# only used for SOAMP
	export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
	if [ -f "${datasource_file}" ]; then
		echo "The datasource ${datasource_file} exists"
	else
		echo "The datasource ${datasource_file} does not exist"
		echo "Provide an alternative datasource name"
		exit 1
	fi
	# only used for SOAMP
	export local_pdb_connect_string=$(grep url ${datasource_file} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
	export dbfs_mount_script=${DOMAIN_HOME}/dbfs/dbfsMount.sh
	export dbfs_mount=$(cat $dbfs_mount_script | grep "MOUNT_PATH=" | head -n 1 | awk -F "=" '{print $2}')
	export ORACLE_HOME=$(cat $dbfs_mount_script | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
	export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
	export PATH=$PATH:$ORACLE_HOME/bin
	if [[ ${PAAS} = "SOAMP" ]]; then
		export copy_folder=$dbfs_mount/share
	elif [[ ${PAAS} = "WLSMP" ]]; then
		export copy_folder=$dbfs_mount/dbfsdir
	fi

	if [[ ${verbose} = "true" ]]; then
		echo "Variable values (for DBFS method):"
		echo " sys_username........................." ${sys_username}
		echo " datasource_name........................." ${datasource_name}
		echo " datasource_file........................." ${datasource_file}
		echo " local_pdb_connect_string............." ${local_pdb_connect_string}
		echo " dbfs_mount_script...................." ${dbfs_mount_script}
		echo " dbfs_mount..........................." ${dbfs_mount}
		echo " copy_folder.........................." ${copy_folder}
		echo " ORACLE_HOME.........................." ${ORACLE_HOME}
	fi
}

######################################################################################################################
############################## FUNCTIONS TO CHECK ####################################################################
######################################################################################################################

checks_in_primary(){
	echo ""
	echo "CHECKS IN PRIMARY"
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		checks_in_primary_RSYNC
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		checks_in_primary_DBFS
	else
		echo "Error. DR topology unknown"
		exit 1
	fi
}

checks_in_primary_RSYNC(){
	echo "Checking ssh connectivity to remote Weblogic Administration server node..."
	export result=$(ssh -o ConnectTimeout=100 -o StrictHostKeyChecking=no -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
	if [ $result == "OK" ];then
		echo "Connectivity to ${REMOTE_ADMIN_NODE_IP} is OK"
		export remote_admin_hostname=$(ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} 'hostname --fqdn')
		echo "remote_admin_hostname......" ${remote_admin_hostname}
		echo ""
	else
		echo "Error: Failed to connect to ${REMOTE_ADMIN_NODE_IP}"
		exit 1
	fi

	# Check local mount  directory
	echo "Checking local FSS ${FSS_MOUNT} folder readiness..."
	if mountpoint -q ${FSS_MOUNT}; then
		echo "Mount at ${FSS_MOUNT} is ready!"
		echo "Will use ${copy_folder} to stage the domain configuration in local site."
		echo ""
		mkdir -p ${copy_folder}
	else
		echo "Error: local FSS mount not available at ${FSS_MOUNT}"
		exit 1
	fi

	# Check remote mount is ready
	echo "Checking remote FSS mount folder readiness..."
	if ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "mountpoint -q ${FSS_MOUNT}";then
		echo "Remote mount at ${REMOTE_ADMIN_NODE_IP}:${FSS_MOUNT} is ready!"
		echo "Will use ${REMOTE_ADMIN_NODE_IP}:${copy_folder} to stage the domain configuration in remote site."
		ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "sudo su - oracle -c \"mkdir -p  ${copy_folder}\" "
	else
		echo "Error: remote FSS mount not ready at ${REMOTE_ADMIN_NODE_IP}:${FSS_MOUNT}."
		exit 1
	fi
}

checks_in_primary_DBFS(){
	echo "Checking DBFS mount point..."
	if mountpoint -q $dbfs_mount; then
		echo "DBFS mount at $dbfs_mount is ready!"
	else
		echo "Error: DBFS Mount point $dbfs_mount not available. Will try to mount again..."
		${dbfs_mount_script}
		sleep 10
		if mountpoint -q $dbfs_mount; then
			echo "Mount at $dbfs_mount is ready."
		else
			echo "Error: DBFS Mount point $dbfs_mount not available even after another try to mount. Check your DBFS set up."
			exit 1
		fi
	fi
}

######################################################################################################################
###################################### FUNCTIONS TO PREPARE PRIMARY ##################################################
######################################################################################################################
setup_primary(){
	echo ""
	echo "SETUP PRIMARY"
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		echo "Do nothing"
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		setup_primary_DBFS
	else
		echo "Error. DR topology unknown"
		exit 1
	fi
}

# Only needed for SOAMP with DBFS
setup_primary_DBFS(){
	# Not re-configuring DBFS anymore (not adding aliases, not changing tnsnames.ora)
	# Only getting and saving primary dbfs user info for being used in secondary in SOAMP
	# In WLS for OCI this is not needed, because DBFS is setup manually with the same user/password
	if [[ ${PAAS} = "SOAMP" ]]; then
		get_dbfs_info
		save_dbfs_info
	fi
}

# Only needed for SOAMP with DBFS
get_dbfs_info(){
	echo "Getting DBFS info..."
	export primary_schema_prefix=$(grep OPSS ${datasource_file} | tr -d "<value>" |sed "s/_OPSS\///g")
	if [[ ${verbose} = "true" ]]; then
		echo "Primary Schema prefix is " $primary_schema_prefix
	fi	
	
	# Gathering DBFS schema password
	export pwdenc=$(grep "<password-encrypted>" ${datasource_file} | awk -F '<password-encrypted>' '{print $2}'  | awk -F '</password-encrypted>' '{print $1}')
	export dbfs_schema_password=$(${exec_path}/fmw_dec_pwd.sh $pwdenc)
}

# Only needed for SOAMP with DBFS
save_dbfs_info(){
	# Saving info in the PDB. This info will be used in standby to recreate dbfs mount wallet and mount DBFS
	# We still need to gather this in this case (SOAMP with DBFS method only) in order to connect to the pdb with the gathered connect string
	export tns_admin=$($exec_path/fmw_get_ds_property.sh $datasource_file 'oracle.net.tns_admin')
	if [ -z "${tns_admin}" ];then
		echo "Error: \$tns_admin property not set in the datasource. Cannot proceed with method DBFS in SOAMP"
		exit 1
	fi
	export TNS_ADMIN=${tns_admin}
	export dbfs_schema_password_encrypted=$(
	echo  "set feed off
	set pages 0
	select DBMS_CRYPTO.encrypt(UTL_RAW.CAST_TO_RAW('$dbfs_schema_password'), 4353 /* = dbms_crypto.DES_CBC_PKCS5 */, UTL_RAW.CAST_TO_RAW ('$SYS_USER_PASSWORD')) from dual;
	exit
	"  | sqlplus -s ${sys_username}/${SYS_USER_PASSWORD}@${local_pdb_connect_string} "as sysdba"
	)

	echo "Saving DBFS info..."
	echo "set feed off
	set feedback off
	set pages 0
	set echo off
	set errorlogging off
	SET SERVEROUTPUT OFF
	Drop table DBFS_INFO;
	set errorlogging on
	SET SERVEROUTPUT ON
	CREATE TABLE DBFS_INFO  (dbfs_prefix VARCHAR(50), dbfs_password VARCHAR(50));
	INSERT INTO DBFS_INFO (dbfs_prefix, dbfs_password) VALUES('$primary_schema_prefix','$dbfs_schema_password_encrypted');
	exit
	"  | sqlplus -s ${sys_username}/${SYS_USER_PASSWORD}@${local_pdb_connect_string} "as sysdba" > /dev/null
	echo "DBFS Information saved!"
}

##end of SOAMP specific functions

######################################################################################################################
############################### FUNCTIONS TO SYNC IN PRIMARY #########################################################
######################################################################################################################

sync_in_primary(){
	echo ""
	echo "SYNC IN PRIMARY"
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		${exec_path}/fmw_sync_in_primary.sh ${DR_METHOD} ${DOMAIN_HOME} ${copy_folder} ${REMOTE_ADMIN_NODE_IP} ${REMOTE_KEYFILE}
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		${exec_path}/fmw_sync_in_primary.sh ${DR_METHOD} ${DOMAIN_HOME} ${copy_folder} 
	else
		echo "Error. DR topology unknown"
		exit 1
	fi
}

######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################


######################################################################################################################
# MAIN
######################################################################################################################
echo ""
echo "FMW DR setup script in PRIMARY site"
echo "This script prepares primary and copies the primary domain to secondary site"
echo "Before running this script make sure that you have followed the steps described in the"
echo "DR document to prepare the environment for the specific DR method you are using."
echo ""
get_DR_method
get_PAAS_type
get_variables
checks_in_primary
setup_primary
sync_in_primary	

echo ""
echo "FINISHED FMW DR setup script"
echo ""

######################################################################################################################
# END OF MAIN
######################################################################################################################

