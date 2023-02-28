#!/bin/bash

##  fmw_dr_setup_standby.sh script version 2.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### Description: Script to set up a standby PaaS service middle tier.
### When run manually, this script should be excuted in EACH one of the standby middle tier nodes.
###
### This script can run in interactive as well as non-interactive mode.  In the interactive
### mode, the user simply runs the script using the script name and the script prompts for all
### required inputs.  In the non-interactive mode, these inputs must be provided as command
### line arguments to the script (See below for usage).
###
### Interactive usage:
###         fmw_dr_setup_standby.sh       (NOTE: User will be prompted for all values)
###
### Non-interactive usage:
### if method DBFS
###         fmw_dr_setup_standby.sh  DR_METHOD [A_DB_IP] [A_PORT] [PDB_SERVICE_PRIMARY] [SYS_DB_PASSWORD]
###         fmw_dr_setup_standby.sh  'DBFS' '129.146.117.58' '1521' 'soapdb.sub19281336420.soacsdrvcn.oraclevcn.com' 'my_sysdba_password'
### if method RSYNC, it only needs
###         fmw_dr_setup_standby_standby.sh DR_METHOD FSS_MOUNT
###	    fmw_dr_setup_standby_standby.sh 'RSYNC' '/u01/share'
###
### Where:
### DR_METHOD   The DR method that is going to be used for the config replication in the DR setup and lifecycle. Can be DBFS or RSYNC:
###             - DBFS:         When using DBFS method.
###                             The domain config replication to secondary site is done via DBFS and Data Guard replica.
###             - RSYNC:        When using FSS with rsync method.
###						The domain config replication to secondary site will be done via rsync.
###
###	A_DB_IP		[ONLY WHEN DR_METHOD IS DBFS]
###				The IP address used to connect to remote primary database from this host. It should be set to:
###				- the database public IP, when remote database is reachable via internet only
###				- the database private IP, when remote database is reachable via Dynamic Routing GW (RECOMMENDED)
###				Note for RAC: If remote db is a RAC, set this value to one of the scan IPs (you MUST use Dynamic Routing Gateway).
###				Ideally scan address name should be used for remote RAC, but that dns name is not usually resolvable from local region.
###
###	A_PORT		[ONLY WHEN DR_METHOD IS DBFS]
###				The port of remote primary database's TNS Listener.
###
###	PDB_SERVICE_PRIMARY	[ONLY WHEN DR_METHOD IS DBFS]
###				The service name of the remote primary PDB. 
###				If you use a CRS service to connect to the PDB, provide it instead the default PDB service.
###
###	SYS_DB_PASSWORD		[ONLY WHEN DR_METHOD IS DBFS]
###						The password for the remote primary database SYS user.
###
### FSS_MOUNT		[ONLY WHEN DR_METHOD IS RSYNC]
###					This is the path to the mount point where the OCI File Storage file system is mounted.
###					This OCI File Storage file system will be used to stage the WLS domain configuration copy.
###					Example: /u01/share

# Check that this is running by oracle
if [ "$(whoami)" != "oracle" ]; then
	echo "Script must be run as user: oracle"
	exit 1
fi

#export verbose=true


######################################################################################################################
# INPUT PARAMETERS SECTION
######################################################################################################################

if [[ $# -ne 0 ]]; then
	export DR_METHOD=$1
	if  [[ $DR_METHOD = "DBFS" ]]; then
                if [[ $# -eq 5 ]]; then
			export A_DB_IP=$2
			export A_PORT=$3
			export PDB_SERVICE_PRIMARY=$4
			export SYS_USER_PASSWORD=$5
		else
			echo ""
			echo "ERROR: Incorrect number of parameters used for DR_METHOD $5. Expected 5, got $#"
			echo "Usage for DR_METHOD=DBFS:"
			echo "      $0 DR_METHOD A_DB_IP  A_PORT  PDB_SERVICE_PRIMARY  SYS_DB_PASSWORD "
			echo "Example: "
			echo "      $0 'DBFS' '10.0.0.11' '1521' 'soapdb.sub19281336420.soacsdrvcn.oraclevcn.com' 'my_sysdba_password'"
			echo ""
			exit 1
		fi

	elif [[ $DR_METHOD = "RSYNC" ]]; then
		if [[ $# -eq 2 ]]; then
			export FSS_MOUNT=$2
		else
			echo ""
			echo "ERROR: Incorrect number of parameters used for DR_METHOD $5. Expected 5, got $#"
			echo "Usage for DR_METHOD=RSYNC:"
			echo "    $0  "
			echo "Example: $0  DR_METHOD FSS_MOUNT"
			echo "    $0   'RSYNC' '/u01/share'"
			echo ""
			exit 1
		fi
	else
		echo ""
		echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $5"
		echo "Usage: "
		echo "	$0 DR_METHOD [A_DB_IP] [A_PORT] [PDB_SERVICE_PRIMARY] [SYS_DB_PASSWORD] [FSS_MOUNT] "
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
		# Get the DB IP address
		echo
		echo "Please enter values for each script input when prompted below:"
		echo
		echo "(2) Enter the IP address used to connect to the primary database from this host."
		echo "    The IP address should be set to:"
		echo "        - the primary database's public IP, when the database is reachable via internet only"
		echo "        - the primary database's private IP, when the database is reachable via Dynamic Routing Gateway."
		echo "        Note: If a RAC database is used, set this value to any one of the RAC database's scan IPs."
		echo
		echo " Enter primary database IP address: "

		read -r A_DB_IP

		# Get the DB port
		echo
		echo "(3) Enter the primary database port number used to connect from this host."
		echo "    Note: this is usually configured as 1521"
		echo
		echo " Enter primary database connect port: "

		read -r A_PORT

		# Get the PDB service name
		echo
		echo "(4) The service name of the pdb used for primary database. "
		echo "    Note: This string has a format similar to pdb1.sub10213758021.soavcnfra.oraclevcn.com"
		echo
		echo " Enter primary PDB service name: "

		read -r PDB_SERVICE_PRIMARY

		# Get the DB SYS password
		while true; do
			echo
			echo "(5) The primary database SYS user's password"
			echo
			echo " Enter the password: "
			read -r -s  PW_STRING1
			echo " Re-enter the password again: "
			read -r -s  PW_STRING2
			[ "$PW_STRING1" = "$PW_STRING2" ] && break
			echo "Passwords do not match. Please try again."
			echo
		done
		SYS_USER_PASSWORD=${PW_STRING1}

	elif  [[ $DR_METHOD = "RSYNC" ]]; then
		# Get the OCI FS file system mount point folder
		echo "(2) Enter the path to the mount point where the OCI File Storage file system is mounted:"
		echo "    Example: /u01/share "
		echo "    This is will be used as staging folder for copying the domain copy."
		echo
		echo " Enter path to the mount point: "
		read -r FSS_MOUNT
	else 
		echo "Error. Invalid DR_METHOD"
		exit 1
	fi
fi
######################################################################################################################
# END OF VARIABLES SECTION
######################################################################################################################

export verbose=true
export date_label=$(date '+%Y-%m-%d-%H_%M_%S')
export exec_path=$(dirname "$0")

# Check dependencies
if [[ ! -x "${exec_path}/fmw_get_dbrole_wlst.sh" ]]; then
	echo "Error. Script ${exec_path}/fmw_get_dbrole_wlst.sh not found or not executable"
	exit 1
fi

if [[ ! -x "${exec_path}/fmw_sync_in_standby.sh" ]]; then
	echo "Error. Script ${exec_path}/fmw_sync_in_standby.sh not found or not executable"
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
	hostnm=$(hostname)
	if [ -d /u01/app/oracle/suite ]; then
		export PAAS=SOAMP
	elif [[ $hostnm == *"-wls-"* ]]; then
		export PAAS=WLSMP
	else
		echo "Error. PAAS service unknown"
		exit 1
	fi
		echo "This PAAS service is ................" $PAAS
}


get_variables(){
	echo ""
	echo "GET AND CHECK VARIABLES"

	# COMMON VARIABLES
	export datasource_name=opss-datasource-jdbc.xml
	export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
	
	if [ -z "${DOMAIN_HOME}" ];then
		echo "\$DOMAIN_HOME is empty. This variable is predefined in the oracle user's .bashrc."
		echo "Example: export DOMAIN_HOME=/u01/data/domains/my_domain"
		exit 1
	fi

	if [ -f "${datasource_file}" ]; then
		echo "The datasource ${datasource_file} exists"
	else
		echo "The datasource ${datasource_file} does not exist"
		echo "Provide an alternative datasource name"
		exit 1
        fi
	
	if [[ ${verbose} = "true" ]]; then	
		echo "Variable values (common):"
		echo " DOMAIN_HOME............................." $DOMAIN_HOME
		echo " datasource_name........................." $datasource_name
	fi
	
	# OTHER VARIABLES THAT DEPEND ON THE DR METHOD
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                get_variables_in_secondary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                get_variables_in_secondary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}

get_variables_in_secondary_RSYNC(){
	export copy_folder=${FSS_MOUNT}/domain_config_copy
	
	if [[ ${verbose} = "true" ]]; then
		echo "Variable values (for RSYNC method):"
		echo " FSS_MOUNT............................" ${FSS_MOUNT}
		echo " copy_folder.........................." ${copy_folder}
	fi
}

get_variables_in_secondary_DBFS(){
	export primary_pdb_connect_string=$A_DB_IP:$A_PORT/$PDB_SERVICE_PRIMARY
	export sys_username=sys
	export dbfs_mount_script=${DOMAIN_HOME}/dbfs/dbfsMount.sh
	export ORACLE_HOME=$(cat $dbfs_mount_script | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
	export dbfs_mount=$(cat $dbfs_mount_script | grep "MOUNT_PATH=" | head -n 1 | awk -F "=" '{print $2}')
	export TNS_ADMIN=$(cat $dbfs_mount_script | grep "TNS_ADMIN=" | head -n 1 | awk -F "=" '{print $2}')
	export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
	export PATH=$PATH:$ORACLE_HOME/bin
	
	if [[ ${PAAS} = "SOAMP" ]]; then
		export dbfs_mount_io=$(cat $dbfs_mount_script | grep "MOUNT_PATH_DIRECTIO=" | head -n 1 | awk -F "=" '{print $2}')
		export dbfs_tns_alias='ORCL'
		export copy_folder=$dbfs_mount/share
	elif [[ ${PAAS} = "WLSMP" ]]; then
		export copy_folder=$dbfs_mount/dbfsdir
	fi

	if [[ ${verbose} = "true" ]]; then
		echo "Variable values (for DBFS method):"
		echo " primary_pdb_connect_string............................" ${primary_pdb_connect_string}
		echo " sys_username.........................................." ${sys_username}
		echo " dbfs_mount_script....................................." ${dbfs_mount_script}
		echo " ORACLE_HOME..........................................." ${ORACLE_HOME}
		echo " dbfs_mount............................................" ${dbfs_mount}
		echo " TNS_ADMIN for dbfs...................................." ${TNS_ADMIN}
		echo " copy_folder..........................................." ${copy_folder}
	fi
	get_db_values_for_dg_conversion
}

# Only needed for DBFS
get_db_values_for_dg_conversion() {
	echo ""
	echo "Getting CDB specific values from the primary DB (sqlplus)............"

	export primary_cdb_unqname=$(
	echo "set feed off
	set pages 0
	select DB_UNIQUE_NAME from V\$DATABASE;
	exit
	"  | sqlplus -s ${sys_username}/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)
	if [[ ${primary_cdb_unqname} = "" ]] ; then
		echo " ERROR: Cannot determine the primary DB unique name"
		exit 1
	fi

	export primary_cdb_dbdomain=$(
	echo "set feed off
	set pages 0
	select value from v\$parameter where name='db_domain';
	exit
	"  | sqlplus -s $sys_username/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)
	if [[ ${primary_cdb_dbdomain} = "" ]] ; then
		echo "ERROR: Cannot determine the primary DB domain"
		exit 1
	fi

	export	primary_cdb_connect_string=${A_DB_IP}:${A_PORT}/${primary_cdb_unqname}.${primary_cdb_dbdomain}

	# This is the only thing not valid when there is a local standby in primary
	export secondary_cdb_unqname=$(
	echo "set feed off
	set pages 0
	select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DEST_ROLE like '%STANDBY%';
	exit
	"  | sqlplus -s $sys_username/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)
	standby_databases=$(echo "${secondary_cdb_unqname}" | wc -w )
	if [[ ${standby_databases} != 1 ]]; then
		echo "ERROR: there are ${standby_databases} standby databases in the Data Guard"
		echo ${secondary_cdb_unqname}
		echo "Cannot determine the secondary database unique name"
		exit 1
	fi

	#get secondary CDB alias string from primary
	export secondary_cdb_tns_string=$(
	echo "set feed off
	set pages 0
	set lines 10000
	SELECT DBMS_TNS.RESOLVE_TNSNAME ('"${secondary_cdb_unqname}"') from dual;
	exit
	"  | sqlplus -s $sys_username/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)
	if [[ ${secondary_cdb_tns_string} = "" ]] ; then
		echo "ERROR: Cannot determine the secondary CDB tns string"
		exit 1
	fi
	# Removing additional CID entry at the end of the string
	secondary_cdb_tns_string=$(echo $secondary_cdb_tns_string  | awk -F '\\(CID=' '{print $1}')
	# Adding required closing parenthesis
	secondary_cdb_tns_string=${secondary_cdb_tns_string}"))"

	
	if [[ ${verbose} = "true" ]]; then
		echo " Primary DB UNIQUE NAME.................." $primary_cdb_unqname		
		echo " Primary DB DOMAIN ......................" $primary_cdb_dbdomain
		echo " Secondary DB UNIQUE NAME................" $secondary_cdb_unqname
		echo " Secondary tns string from primary ......" $secondary_cdb_tns_string
	fi

}

######################################################################################################################
############################## FUNCTIONS TO CHECK ####################################################################
######################################################################################################################
checks_in_secondary(){
	echo ""
	echo "CHECKS IN SECONDARY"
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		checks_in_secondary_RSYNC
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		checks_in_secondary_DBFS_for_setup
	else
		echo "Error. DR topology unknown"
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


checks_in_secondary_DBFS_for_setup(){
	echo "Checking if standby is in physical or snapshot standby..."
	export jdbc_url="jdbc:oracle:thin:@"${secondary_cdb_tns_string}
	export username=${sys_username}
	export password=${SYS_USER_PASSWORD}
	export db_role=$(${exec_path}/fmw_get_dbrole_wlst.sh ${username} ${password} ${jdbc_url} )
	echo "Secondary database role is $db_role "
	if  [[ ${db_role} = *"PHYSICAL STANDBY"* ]];then
		echo "Database is in the expected mode. Continuing with the setup.."
	elif [[ ${db_role} = *"SNAPSHOT STANDBY"* ]];then
		echo "Error: secondary database must be in physical standby mode."
		exit 1
	fi
	# The dbfs mount is checked later in setup_secondary step,
	# once the db is converted to snapshot
}

######################################################################################################################
###################################### FUNCTIONS TO BACKUP sECONDARY #################################################
######################################################################################################################

create_domain_backup() {
	echo ""
	echo "BACKUP SECONDARY DOMAIN"
	echo "Backing up domain to backup dir: ${DOMAIN_HOME}_backup_$date_label ..."
	cp -R ${DOMAIN_HOME}/ ${DOMAIN_HOME}_backup_$date_label
	echo "Backup created!"
}


######################################################################################################################
###################################### FUNCTIONS TO PREPARE SECONDARY #################################################
######################################################################################################################

setup_secondary(){
	echo ""
	echo "PREPARE SECONDARY"
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		echo "RSYNC method, do nothing"
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		setup_secondary_DBFS
	else
		echo "Error. DR topology unknown"
		exit 1
	fi
}

# Only needed for DBFS
setup_secondary_DBFS(){
	# In WLS DR: convert to snapshot, mount dbfs (not need to re-configure dbfs because it is already configured with dbfs_root script)
	# In SOAMP: convert to snapshot, recreate wallet, mount dbfs
	convert_standby "SNAPSHOT STANDBY"
	# Additional steps for SOAMP only
	if [[ ${PAAS} = "SOAMP" ]]; then
		get_dbfs_info_from_pdb
		recreate_dbfs_wallet
	fi
	check_and_retry_dbfs_mount
}

# Only needed for DBFS
convert_standby(){
	standby_req_status=$1
	echo "Converting standby to $standby_req_status"
	export conversion_result=$(
	dgmgrl ${sys_username}/\'${SYS_USER_PASSWORD}\'@\"${primary_cdb_connect_string}\"  "convert database '${secondary_cdb_unqname}' to ${standby_req_status}"
	)
	if [[ $conversion_result = *successful* ]];then
		echo "Standby DB Converted to $standby_req_status !"
	else
		echo "DB CONVERSION FAILED. CHECK DATAGUARD STATUS."
		exit 1
	fi
}


# Only needed for DBFS method in SOAMP
get_dbfs_info_from_pdb(){
	export primary_schema_prefix=$(
	echo  "set feed off
	set pages 0
	select dbfs_prefix from DBFS_INFO;
	exit
	"  | sqlplus -s $sys_username/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)

	export dbfs_schema_password_encrypted=$(
	echo  "set feed off
	set pages 0
	select dbfs_password from DBFS_INFO;
	exit
	"  | sqlplus -s $sys_username/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)
	
	export dbfs_schema_password=$(
	echo  "set feed off
	set pages 0
	select UTL_RAW.CAST_TO_varchar2(DBMS_CRYPTO.decrypt('$dbfs_schema_password_encrypted', 4353,  UTL_RAW.CAST_TO_RAW ('$SYS_USER_PASSWORD'))) from dual;
	exit
	"  | sqlplus -s $sys_username/${SYS_USER_PASSWORD}@${primary_pdb_connect_string} "as sysdba"
	)
}
# Only needed for DBFS method in SOAMP
recreate_dbfs_wallet(){
	unset ORACLE_HOME
	echo "Unmounting current dbfs mounts..."
	fusermount -u $dbfs_mount_io
	fusermount -u $dbfs_mount
	echo "Unmounted!"
	mv ${TNS_ADMIN}/wallet/ ${TNS_ADMIN}/wallet_backup_$date_label

	echo "Creating new wallet..."
	printf ${SYS_USER_PASSWORD}'\n'${SYS_USER_PASSWORD}'\n' | ${MIDDLEWARE_HOME}/oracle_common/bin/mkstore -wrl ${DOMAIN_HOME}/dbfs/wallet/ -create > /dev/null
	echo "Wallet created!"
	echo "Adding credential to the wallet..."
	export add_cred_command="-createCredential ${dbfs_tns_alias} ${primary_schema_prefix}_DBFS ${dbfs_schema_password}"
	printf ${SYS_USER_PASSWORD}'\n' | ${MIDDLEWARE_HOME}/oracle_common/bin/mkstore -wrl ${DOMAIN_HOME}/dbfs/wallet/ ${add_cred_command} > /dev/null
	echo "New credential added!"
	echo "Mounting DBFS points again..."
	${dbfs_mount_script}
	sleep 10
}

# Only needed for DBFS
check_and_retry_dbfs_mount() {
	echo "Checking DBFS mount point..."
	if mountpoint -q $dbfs_mount; then
		echo "Mount at $dbfs_mount is ready!"
	else
		echo "DBFS Mount point not available. Will try to mount again..."
		${dbfs_mount_script}
		sleep 10
		if mountpoint -q $dbfs_mount; then
			echo "Mount at $dbfs_mount is ready."
		else
			echo "Error: DBFS Mount point not available even after another try to mount. Check your DBFS set up."
			exit 1
		fi
	fi
}

######################################################################################################################
############################### FUNCTIONS TO SYNC IN SECONDARY #########################################################
######################################################################################################################

sync_in_secondary(){
	echo ""
	echo "SYNC IN SECONDARY"
	${exec_path}/fmw_sync_in_standby.sh ${DR_METHOD} ${DOMAIN_HOME} ${copy_folder}
}

######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################


######################################################################################################################
# MAIN
######################################################################################################################
echo 
echo "FMW DR setup script in SECONDARY site"
echo " Before running this script make sure of the following:"
echo " 1.- FMW DR setup primary script has been run in the primary WLS Administration server node"
echo " 2.- Node manager and WLS servers are stopped in this node"
echo " 3.- If using DBFS method, the database is physical standby (not a snapshot standby)"
echo " 4.- You have provided the required parameters (as input or interactively)"
echo " 5.- You have followed the steps described in the DR document to prepare"
echo "     the environment for the specific DR method you are using."
echo
echo

get_DR_method
get_PAAS_type
get_variables
checks_in_secondary
create_domain_backup
setup_secondary
sync_in_secondary

echo 
echo "FINISHED"

######################################################################################################################
# END OF MAIN
######################################################################################################################
