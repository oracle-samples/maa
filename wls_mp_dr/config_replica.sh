#!/bin/bash

## PaaS DR scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


#config_replica.sh
### This script should be executed in the WLS Administration Node (either primary or standby).
### This script checks the current role of the database to determine if it is running in primary or standby site.
### When it runs in PRIMARY site: 
###	it copies the domain config from primary domain to local assistance folder (DBFS or FSS), 
##	and then to the secondary site assistance folder (via FSS/rsync or DBFS/DG replica).
### When it runs in STANDBY site: 
###	it copies the domain config from the secondary assistance folder (DBFS or FSS) to the secondary domain, and makes the required replacements.
###
### This script depends on the appropriate execution of the fmw_primary and fmw_standy DR setup scripts (or alternatively, the appropiate execution of the DRS tool).         
### Usage:
###
### - Option 1) Setting custom parameters in the script
###   You can hardcode the custom parameters in this script, so no input parameters are passed.
###   For this, set the values in the "CUSTOMIZED PARAMETERS SECTION" in the script. This is useful to cron the script.
###
### - Option 2) Provide parameters as input
###   You can pass the parameters as input. The syntax is the following:
###   ./config_replica.sh <DR_METHOD> [REMOTE_ADMIN_NODE_IP] [REMOTE_KEYFILE]
###	where:
###	DR_METHOD:		The DR Method used. It should be set to:
###					- DBFS:		When using DBFS method. 
###							The domain config replication to secondary site is done via Data Guard replica using a DBFS mount as assistance 
###							filesystem.
###					- RSYNC:	When using FSS with rsync method. 
###							The domain config replication to the secondary site will be done via rsync, using a FSS mount as assisntance 
###							filesystem. This script assumes that the FSS is mounted in /fssmount.
###
###	REMOTE_ADMIN_NODE_IP:	[ONLY WHEN DR_METHOD IS RSYNC]. It is the remote Weblogic Administration server node IP, for remote rsync commands. 
###   				It needs to be reachable from local node. It is recommended to connect to the remote private ip, via Dynamic Routing Gateway.
###
###	REMOTE_KEYFILE:		[ONLY WHEN DR_METHOD IS RSYNC]. The private ssh keyfile to connect to remote Weblogic Administration server node.
###
###	The SYS_USER_PASSWORD will be requested interactively

#export VERBOSE=true

# To get input customizable parameters
if [[ $# -ne 0 ]]; then
	export DR_METHOD=$1
	if  [[ $DR_METHOD = "DBFS" ]]; then
                if [[ $# -eq 1 ]]; then
                        echo
		else
			echo ""
			echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 1, got $#"
			echo "Usage for DR_METHOD=DBFS:" 
			echo "      $0  DR_METHOD "
			echo "Example: "
			echo "      $0 'DBFS' "
			echo ""
			exit 1
		fi
	
	elif [[ $DR_METHOD = "RSYNC" ]]; then
		if [[ $# -eq 3 ]]; then
			export REMOTE_ADMIN_NODE_IP=$2
			export REMOTE_KEYFILE=$3
		else
			echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 3, got $#"
			echo "Usage for DR_METHOD=RSYNC:"
			echo "    $0  DR_METHOD REMOTE_ADMIN_NODE_IP REMOTE_KEYFILE"
			echo "Example:  "
			echo "    $0  'RSYNC' '10.1.2.43' '/u01/install/KeyWithoutPassPhraseSOAMAA.ppk'"
			echo ""
			exit 1
		fi
	else
		echo ""
		echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $1"
		echo ""
		exit 1
	fi


else
	echo ""
	echo "WARNING: No parameters passed as input. Values set in the script will be used"
	###############################################################################################################
	################## BEGIN CUSTOMIZED PARAMETERS SECTION ########################################################
	###############################################################################################################
	# In case the parameters are not passed as input parameters they can be hardcoded here
	export DR_METHOD=
	export REMOTE_ADMIN_NODE_IP=   		# Required only for RSYNC method
	export REMOTE_KEYFILE=			# Required only for RSYNC method
	#[OPTIONAL] You can set the encrypted sys password here. If not, you will be prompted to enter it interactively
	#Check the whitepaper for instructions to encrypt it
	#Example of encrypted sys password
	#export ENCRYPTED_SYS_USER_PASSWORD={AES256}DVJKPjS0Yw9o+rM/DcbjIPfEhdxq3oPDrppFsLFmU2b3i3ya9lR/ZtzJMKNbZvmT
	export ENCRYPTED_SYS_USER_PASSWORD=
	###############################################################################################################
	################## END OF CUSTOMIZED PARAMATERS SECTION #######################################################
	###############################################################################################################
        echo " DR_METHOD							= $DR_METHOD "
        echo " REMOTE_ADMIN_NODE_IP (required only for RSYNC DR METHOD)	= $REMOTE_ADMIN_NODE_IP"
        echo " REMOTE_KEYFILE       (required only for RSYNC DR METHOD)	= $REMOTE_KEYFILE"
	echo " ENCRYPTED_SYS_USER_PASSWORD					= <value_not_shown>"
	sleep 10
fi


######################################################################################################################
# FUNCTIONS
######################################################################################################################
get_DR_method(){
	echo ""
        echo "************** GET DR TOPOLOGY METHOD *******************************************"
	echo "Check whether DR topology is based on DBFS or remote RSYNC..."
	if  [[ $DR_METHOD = "RSYNC" ]] || [[ $DR_METHOD = "DBFS" ]]; then
		echo "This DR topology is based on.........." $DR_METHOD
	else
		echo "ERROR: DR topology unknown"
		exit 1
	fi
	echo ""
}

get_PAAS_type(){
	# Determining if WLSMP or SOAMP using the hostname naming
	# (not valid for SOACS)
	hostnm=$(hostname)
	if [ -d /u01/app/oracle/suite ]; then
		export PAAS=SOAMP
	elif [[ $hostnm == *"-wls-"* ]]; then
		export PAAS=WLSMP
	else
		echo "Error. PAAS service unknown"
		exit 1
	fi

	if [[ ${VERBOSE} = "true" ]]; then
		echo "This PAAS service is ................" $PAAS
	fi
}

get_variables(){
	echo ""
	echo "************** GET VARIABLES *****************************************************"
	get_PAAS_type
	# COMMON VARIABLES
	export date_label=$(date '+%d-%m-%Y-%H-%M-%S')
	
	if [ -z "${DOMAIN_HOME}" ];then
		echo "\$DOMAIN_HOME is empty. This variable is predefined in the oracle user's .bashrc. Example: export DOMAIN_HOME=/u01/data/domains/my_domain"
		exit 1
	else
		export WLS_DOMAIN_NAME=$(echo ${DOMAIN_HOME} |awk -F '/u01/data/domains/' '{print $2}')
	fi

	export DATASOURCE_NAME=opss-datasource-jdbc.xml
        if [ -f "${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}" ]; then
                echo "The datasource ${DATASOURCE_NAME} exists"
        else
                echo "The datasource ${DATASOURCE_NAME} does not exist"
                echo "Provide an alternative datasource name"
                exit
        fi

        export LOCAL_JDBC_URL=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
        # For RAC ONS list update. This will be null for non-rac cases
        export LOCAL_ONS_ADDRESS=$(grep ons-node-list ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '[<>]' '{print $3}')

        export CDB_SERVICE_FILE=/u01/data/domains/local_CDB_jdbcurl.nodelete
	if [ -f "$CDB_SERVICE_FILE" ]; then
		echo "Local CDB file found. Proceeding"
		export LOCAL_CDB_URL=$(head -n 1 $CDB_SERVICE_FILE)
	        #export LOCAL_CDB_URL=$(cat $CDB_SERVICE_FILE)
	else
		echo "$CDB_SERVICE_FILE not found. Please make sure that your system has been configured for DR using fmw DR setup scripts (or DRS tool)"
		exit 1
	fi

	if [[ ${VERBOSE} = "true" ]]; then
        	echo "VARIABLES VALUES (COMMON):"
		echo " PAAS type is ........................" ${PAAS}
		echo " DATASOURCE_NAME is .................." ${DATASOURCE_NAME}
        	echo " DOMAIN_HOME is ......................" ${DOMAIN_HOME}
        	echo " WLS_DOMAIN_NAME is .................." ${WLS_DOMAIN_NAME}
        	echo " LOCAL_CDB_URL........................" ${LOCAL_CDB_URL}
        	echo " LOCAL_JDBC_URL......................." ${LOCAL_JDBC_URL}
	fi

	# VARIABLES FOR REMOTE RSYNC METHOD
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		# Pre-fixed values
		export FSS_MOUNT=/fssmount
		export COPY_FOLDER=${FSS_MOUNT}/domain_config_copy
		
	        if [[ ${VERBOSE} = "true" ]]; then
			echo "VARIABLES VALUES (FOR REMOTE RSYNC METHOD):"
			echo " FSS_MOUNT............................" ${FSS_MOUNT}
			echo " COPY_FOLDER.........................." ${COPY_FOLDER}
			echo " REMOTE_ADMIN_NODE_IP................." ${REMOTE_ADMIN_NODE_IP}
			echo " REMOTE_KEYFILE......................." ${REMOTE_KEYFILE}
		fi

	# VARIABLES FOR DBFS
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		export DBFS_MOUNT_SCRIPT=${DOMAIN_HOME}/dbfs/dbfsMount.sh
		export ORACLE_HOME=$(cat $DBFS_MOUNT_SCRIPT | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
		export DBFS_MOUNT=$(cat $DBFS_MOUNT_SCRIPT | grep "MOUNT_PATH=" | head -n 1 | awk -F "=" '{print $2}')
		# IF SOAMP
		if [[ ${PAAS} = "SOAMP" ]]; then
			export DBFS_MOUNT_PATH=$DBFS_MOUNT/share
		# IF WLS OCI
		elif [[ ${PAAS} = "WLSMP" ]]; then
			export DBFS_MOUNT_PATH=$DBFS_MOUNT/dbfsdir
		fi
		export TNS_ADMIN=$(cat $DBFS_MOUNT_SCRIPT | grep "TNS_ADMIN=" | head -n 1 | awk -F "=" '{print $2}')
		export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
		export PATH=$PATH:$ORACLE_HOME/bin
		export SYS_USERNAME=sys
		export LOCAL_DB_FILE=${DOMAIN_HOME}/dbfs/localdb.log
		if [ -f "$LOCAL_DB_FILE" ]; then
		        echo "Local DB file found. Proceeding"
        		#export LOCAL_DB_UNQNAME=$(cat $LOCAL_DB_FILE)
			#Changed to support local DG. 
			#This is used only when this site is standby role, to convert it to snapshot
			#in case the standby site has 2 local db, we will convert the first one
			#Taking the first line will be valid in all the cases (with local DG or not)
			#NOTE: in fact we may not need to add the local DG name to this "pointer file"
			export LOCAL_DB_UNQNAME=$(head -n 1 $LOCAL_DB_FILE)
		else
		        echo "$LOCAL_DB_FILE not found. Please make sure that your system has been configured for DR using DBFS method"
			exit 1
		fi

	        if [[ ${VERBOSE} = "true" ]]; then
			echo "VARIABLES VALUES (FOR DBFS METHOD):"
			echo " DBFS_MOUNT_SCRIPT...................." ${DBFS_MOUNT_SCRIPT}
			echo " ORACLE_HOME.........................." ${ORACLE_HOME}
			echo " DBFS_MOUNT..........................." ${DBFS_MOUNT}
			echo " DBFS_MOUNT_PATH......................" ${DBFS_MOUNT_PATH}
			echo " TNS_ADMIN............................" ${TNS_ADMIN}
			echo " SYS_USERNAME........................." ${SYS_USERNAME}
			echo " LOCAL_DB_FILE........................" ${LOCAL_DB_FILE}
			echo " LOCAL_DB_UNQNAME....................." ${LOCAL_DB_UNQNAME}
		fi
	else
		echo "Error. DR topology unknown"
		exit 1
	fi		
	echo ""
}



get_localdb_role(){
	echo ""
        echo "************** GET LOCAL DB ROLE *************************************************"
	export count=0;
	export top=3;
	while [ $count -lt  $top ]; do
		echo "Checking current database role"
		if [ -z "$ENCRYPTED_SYS_USER_PASSWORD" ];then
			echo "Enter the database SYS password (clear): "
			read -r -s SYS_USER_PASSWORD
		else
			echo "domain='${DOMAIN_HOME}'" > /tmp/pret.py
			echo "service=weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain)" >>/tmp/pret.py
			echo "encryption=weblogic.security.internal.encryption.ClearOrEncryptedService(service)" >>/tmp/pret.py
			echo "print encryption.decrypt('${ENCRYPTED_SYS_USER_PASSWORD}')"  >>/tmp/pret.py
			export SYS_USER_PASSWORD=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/pret.py | tail -1)
			rm /tmp/pret.py
		fi
		export jdbc_url="jdbc:oracle:thin:@"$LOCAL_CDB_URL
		export username="sys as sysdba"
		export password=${SYS_USER_PASSWORD}
		echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_local_role.py
		echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_local_role.py
		echo "username = \"$username\" " >> /tmp/get_local_role.py
		echo "password = \"$password\" " >> /tmp/get_local_role.py
		echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_local_role.py
		echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_local_role.py
		echo "cursor = conn.cursor(1)" >> /tmp/get_local_role.py
		echo "cursor.execute(\"select database_role from v\$database\")" >> /tmp/get_local_role.py
		echo "print cursor.fetchone()" >> /tmp/get_local_role.py
		export db_role=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_local_role.py | tail -1)
		echo "The role of the database is: ${db_role}"

		# Added to support LOCAL DG 
                # Check also the role of the local DG
		# Because in case of a local switchover, the role site is still primary
		lines=$(cat $CDB_SERVICE_FILE | wc -l)
		if [[ $lines = "2" ]]; then
			echo "   The file $CDB_SERVICE_FILE contains 2 lines. This site has a local Data Guard"
	                # In case a local switchover, the role site is still primary
                	echo "   Checking the role of the additional local database..."
                        export LOCAL_CDB_URL_2=$(head -2 $CDB_SERVICE_FILE | tail -1)
                        export jdbc_url="jdbc:oracle:thin:@"${LOCAL_CDB_URL_2}
                        export username="sys as sysdba"
                        export password=${SYS_USER_PASSWORD}
                        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_local_role.py
                        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_local_role.py
                        echo "username = \"$username\" " >> /tmp/get_local_role.py
                        echo "password = \"$password\" " >> /tmp/get_local_role.py
                        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_local_role.py
                        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_local_role.py
                        echo "cursor = conn.cursor(1)" >> /tmp/get_local_role.py
                        echo "cursor.execute(\"select database_role from v\$database\")" >> /tmp/get_local_role.py
                        echo "print cursor.fetchone()" >> /tmp/get_local_role.py
                        export db_role_2=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_local_role.py | tail -1)
                        echo "   The role of the local DG database is: " ${db_role_2}
                        if  [[ ${db_role} = *PRIMARY* ]] || [[ ${db_role_2} = *PRIMARY* ]]; then
                                db_role="PRIMARY"
				echo "The role of this SITE is $db_role"
			fi
                fi
		# End of code to support LOCAL DG 


		if  [[ ${db_role} = *PRIMARY* ]] || [[ ${db_role} = *STANDBY* ]]; then
	   	echo "Sys password is valid. Proceeding..."
	   	count=3
		   return 0
		else
		   echo "Invalid password or incorrect DB status";
		   echo "Check that you can connect to the DB and that Data Guard has been configured."
		   count=$(($count+1));
		   if [ $count -eq 3 ]; then
		        echo "Maximum number of attempts exceeded, review you login to the DB"
		        return 1
		   fi
		fi
	done
	echo ""
}


retrieve_remote_connect_info(){
	echo ""
	echo "************** RETRIEVE REMOTE CONNECT INFO ***************************************"
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		export REMOTE_JDBC_URL=$(grep url ${COPY_FOLDER}/$WLS_DOMAIN_NAME/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
		export REMOTE_ONS_ADDRESS=$(grep ons-node-list ${COPY_FOLDER}/${WLS_DOMAIN_NAME}/config/jdbc/${DATASOURCE_NAME} | awk -F '[<>]' '{print $3}')
	elif [[ ${DR_METHOD} = "DBFS" ]];then
		export REMOTE_JDBC_URL=$(grep url $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
		export REMOTE_ONS_ADDRESS=$(grep ons-node-list ${DBFS_MOUNT_PATH}/${WLS_DOMAIN_NAME}/config/jdbc/${DATASOURCE_NAME} | awk -F '[<>]' '{print $3}')
	else
		echo "Error. DR topology unknown"
		exit 1
	fi
	echo "Remote Connect String................" $REMOTE_JDBC_URL
	echo ""
}

checks_in_primary(){
        echo ""
        echo "************** CHECKS IN PRIMARY *** *******************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                checks_in_primary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                checks_in_primary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}


checks_in_primary_RSYNC(){
        # Check connectivity to remote Weblogic Administration server node and show its hostname
        echo " Checking ssh connectivity to remote Weblogic Administration server node...."
        export result=$(ssh -o ConnectTimeout=100 -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
        if [ $result == "OK" ];then
                echo "    Connectivity to ${REMOTE_ADMIN_NODE_IP} is OK"
                export REMOTE_ADMIN_HOSTNAME=$(ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} 'hostname --fqdn')
                echo "    REMOTE_ADMIN_HOSTNAME......" ${REMOTE_ADMIN_HOSTNAME}
        else
                echo "    Error: Failed to connect to ${REMOTE_ADMIN_NODE_IP}"
                exit 1
        fi

        # Check local mount is ready
        echo " Checking local FSS mount folder readiness........"
	echo "     The FSS is expected to be mounted in ${FSS_MOUNT}"
	echo "     The folder for the copy of the domain is expected to be ${COPY_FOLDER}"
        if [ -d "${COPY_FOLDER}" ];then
                echo "     Local folder ${COPY_FOLDER} exists."
        else
                echo "     Error: Local folder ${COPY_FOLDER} does not exists."
                exit 1
        fi

        # Check remote mount is ready
        echo " Checking remote FSS mount folder readiness........"
        if ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} [ -d ${COPY_FOLDER} ];then
                echo "     Remote folder ${REMOTE_ADMIN_NODE_IP}:${COPY_FOLDER} exists."
        else
                echo "     Error: remote folder  ${REMOTE_ADMIN_NODE_IP}:${COPY_FOLDER} does not exist."
                exit 1
        fi
}

checks_in_primary_DBFS(){
	# Check if dbfs mount is available and remount if needed
	echo "Checking DBFS mount point..."
	if mountpoint -q $DBFS_MOUNT; then
		echo "    Mount at $DBFS_MOUNT is ready!"
		return 1
	else
		echo "    DBFS Mount point not available. Will try to mount again..."
		${DBFS_MOUNT_SCRIPT}
		sleep 10
		if mountpoint -q $DBFS_MOUNT; then
			echo "    Mount at $DBFS_MOUNT is ready!"
		else
			echo "    Error: DBFS Mount point not available even after another try to mount. Check your DBFS set up."
            exit 1
		fi
	fi
}

checks_in_secondary(){
        echo ""
        echo "************** CHECKS IN SECONDARY  *******************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                checks_in_secondary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                checks_in_secondary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}


checks_in_secondary_RSYNC(){
        echo " Checking local FSS mount folder readiness........"
        echo "     The FSS is expected to be mounted in ${FSS_MOUNT}"
        echo "     The folder for the copy of the domain is expected to be ${COPY_FOLDER}"

        if [ -d "${COPY_FOLDER}" ];then
                echo "     Local folder ${COPY_FOLDER} exists."
        else
                echo "     Error: Local folder ${COPY_FOLDER} does not exists."
                exit 1
        fi
}

checks_in_secondary_DBFS(){
	# if PHYSICAL STANDBY
	#  convert_to_snapshot. DB CLIENT needed for this
	#  check dbfs mount and retry if needed
	# if SNAPSHOT STANDBY
	#  check dbfs mount and retry if needed
	echo " Checking if standby is in physical or snapshot standby ......."
	retrieve_remote_unq_name
	if [[ $db_role = *"PHYSICAL STANDBY"* ]]; then
		echo "    Standby DB is in physical standby status"
		export STANDBY_REQ_STATUS="snapshot standby"
		convert_standby
	else
		echo "    Standby DB is already in snapshot standby status"
	fi
	echo " Checking the DBFS mount...."
	check_and_retry_mount
	check_and_retry_mount_result=$?
	if [ "$check_and_retry_mount_result" == 1 ]; then
		echo "    DBFS Mount is ready"
	else
	        echo "	  Error: DBFS mount available. Cannot copy domain configuration data from DBFS."
		exit 1
        fi	
}

retrieve_remote_unq_name(){
	#select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DB_UNIQUE_NAME != '${LOCAL_DB_UNQNAME}';
	# Lets retrieve the one that is the primary role
	# This function runs always when site is standby
	# So this will retrieve the remote DB unique name of the DB that is primary (regardless local DGs)
	export REMOTE_DB_UNQNAME=$(
	echo "set feed off
	set pages 0
	alter session set NLS_COMP=ANSI;
	alter session set NLS_SORT=BINARY_CI;
	select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DEST_ROLE like '%PRIMARY%';
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@$LOCAL_DB_UNQNAME "as sysdba"
	)

	if [[ ${VERBOSE} = "true" ]]; then	
		echo "Remote UNQ (primary DB)"  $REMOTE_DB_UNQNAME
	fi
}


convert_standby(){
	echo "Converting standby db to $STANDBY_REQ_STATUS"
	#We connect dgmgr to remote DB since that is the primary
	export conversion_result=$(
	dgmgrl ${SYS_USERNAME}/${SYS_USER_PASSWORD}@${REMOTE_DB_UNQNAME}  "convert database '${LOCAL_DB_UNQNAME}' to ${STANDBY_REQ_STATUS}"

	)
	if [[ $conversion_result = *successful* ]]
        then
        	echo "Standby DB Converted to $STANDBY_REQ_STATUS !"
	else
        	echo "DB CONVERSION FAILED. CHECK DATAGUARD STATUS."
        	exit 1
	fi
}

check_and_retry_mount(){
	echo "Checking DBFS mount point..."
	if mountpoint -q $DBFS_MOUNT; then
        	echo "Mount at $DBFS_MOUNT is ready!"
		return 1
	else
        	echo "DBFS Mount point not available. Will try to mount again..."
	        ${DBFS_MOUNT_SCRIPT}
        	sleep 10
        	if mountpoint -q $DBFS_MOUNT; then
			echo "    Mount at $DBFS_MOUNT is ready."
			return 1
		else
                	echo "    Error: DBFS Mount point not available even after another try to mount. Check your DBFS set up."
	                echo "    If the DB does not allow read-only mode and it is a pshysical standby, this is expected."
        	        return 0
	        fi
	fi
}



sync_in_primary(){
        echo ""
        echo "************** SYNC IN PRIMARY *** *******************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
		sync_in_primary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
        	sync_in_primary_DBFS
	else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}
	
sync_in_primary_RSYNC(){
	# If WLSMP, in RSYNC method there is no dbfs folder
	# If SOAMP, in RSYNC method there is dbfs folder and but it is not modified during DR setup. We can replicate it except the tnsnames.ora (which is and must be 
	# different in each site)
	export exclude_list="--exclude 'dbfs/tnsnames.ora' --exclude 'soampRebootEnv.sh' "
	export exclude_list="$exclude_list --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' "
        export exclude_list="$exclude_list --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp' "
        export exclude_list="$exclude_list --exclude 'servers/*/adr/diag/ofm/*/*/lck/*.lck' --exclude 'servers/*/adr/oracle-dfw-*/sampling/jvm_threads*' "
	export exclude_list="$exclude_list --exclude 'tmp'"
	export exclude_list="$exclude_list --exclude '/nodemanager'"

	# First, a copy to local FSS mount folder
	echo "----------- Rsyncing from local domain to local FSS folder... ------------"
	export rsync_log_file=${COPY_FOLDER}/last_primary_update_local_${date_label}.log
	export diff_file=${COPY_FOLDER}/last_primary_update_local_${date_label}_diff.log
	echo "Local rsync output to ${rsync_log_file} ...."

	ORIGIN_FOLDER="${DOMAIN_HOME}/"
	DEST_FOLDER="${COPY_FOLDER}/${WLS_DOMAIN_NAME}"
	export local_rsync_command="rsync -avz --stats --modify-window=1 $exclude_list $ORIGIN_FOLDER $DEST_FOLDER "
	eval $local_rsync_command >> ${rsync_log_file}
	
	export local_rsync_compare_command="rsync -niaHc ${exclude_list} $ORIGIN_FOLDER $DEST_FOLDER --modify-window=1"
	export local_sec_rsync_command="rsync --stats --modify-window=1 --files-from=${diff_file}_pending $ORIGIN_FOLDER $DEST_FOLDER "
        export rsync_compare_command=${local_rsync_compare_command}
	export sec_rsync_command=${local_sec_rsync_command}
	compare_rsync_diffs
	
        echo " "
        echo "----------- Local rsync complete ------------------------------------------"

	# Then, copy from the local FSS mount folder to remote node (no in-flight changes)
	echo " "
        echo "----------- Rsyncing from local FSS folder to remote site... --------------"
        export rsync_log_file=${COPY_FOLDER}/last_primary_update_remote_${date_label}.log
        export diff_file=${COPY_FOLDER}/last_primary_update_remote_${date_label}_diff.log
	echo "Remote rsync output to ${rsync_log_file} ...."

	ORIGIN_FOLDER="${COPY_FOLDER}/${WLS_DOMAIN_NAME}/"
	DEST_FOLDER="${COPY_FOLDER}/${WLS_DOMAIN_NAME}"

	# We need to sudo to oracle because if not, the files are created with the user opc
	export remote_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_KEYFILE}\" -avz --stats --modify-window=1 $exclude_list $ORIGIN_FOLDER opc@${REMOTE_ADMIN_NODE_IP}:${DEST_FOLDER}"
	eval $remote_rsync_command >> ${rsync_log_file}
		
	export remote_rsync_compare_command="rsync --rsync-path \"sudo -u oracle rsync\"  -e \"ssh -i ${REMOTE_KEYFILE}\" -niaHc ${exclude_list} ${ORIGIN_FOLDER} opc@${REMOTE_ADMIN_NODE_IP}:${DEST_FOLDER} --modify-window=1"
	export remote_sec_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_KEYFILE}\" --stats --modify-window=1 --files-from=${diff_file}_pending ${ORIGIN_FOLDER} opc@${REMOTE_ADMIN_NODE_IP}:${DEST_FOLDER}"
	export rsync_compare_command=${remote_rsync_compare_command}
	export sec_rsync_command=${remote_sec_rsync_command}
	compare_rsync_diffs       
        echo " "
	echo "------------ Remote rsync complete-------------------------------------------"
}

compare_rsync_diffs(){
        export max_rsync_retries=4
	stilldiff="true"
	while [ $stilldiff == "true" ]
	do
		eval $rsync_compare_command > $diff_file  # THIS COMMAND IS DEFINED BEFORE CALLING THIS FUNCTION
		echo "Checksum comparison of source and target dir completed." >> $rsync_log_file
		compare_result=$(cat $diff_file | grep -v  '.d..t......' | grep -v  'log' | grep -v  'DAT' | wc -l)
		echo "$compare_result number of differences found" >> $rsync_log_file
		if [ $compare_result -gt 0 ]; then
			((rsynccount=rsynccount+1))
			if [ "$rsynccount" -eq "$max_rsync_retries" ];then
				stilldiff="false"
				echo "Maximum number of retries reached" 2>&1 | tee -a $rsync_log_file
				echo "******************************WARNING:************************************************************" 2>&1 | tee -a $rsync_log_file
				echo "Copy of config was retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a $rsync_log_file
				echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a $rsync_log_file
				echo "This may be caused by logs and/or DAT files being modified by the source domain while performing the rsync operation." 2>&1 | tee -a $rsync_log_file
				echo "It is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a $rsync_log_file
				echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers" 2>&1 | tee -a $rsync_log_file
				echo "after running the config_replica.sh in the standby site." 2>&1 | tee -a $rsync_log_file
				echo "**************************************************************************************************" 2>&1 | tee -a $rsync_log_file

			else
				stilldiff="true"
				echo "Differences are: " >> $rsync_log_file
				cat $diff_file >> $rsync_log_file
				cat $diff_file |grep -v  '.d..t......'  |grep -v  'log' | awk '{print $2}' > ${diff_file}_pending
				echo "Trying to rsync again the differences" >> $rsync_log_file
				echo "Rsyncing the pending files..." >> $rsync_log_file
				eval $sec_rsync_command >> $rsync_log_file  # THIS COMMAND IS DEFINED BEFORE CALLING THIS FUNCTION
				echo "RSYNC RETRY NUMBER $rsynccount" >> $rsync_log_file
			fi
		else
			stilldiff="false"
			echo "Source and target directories are in sync. ALL GOOD!" 2>&1 | tee -a $rsync_log_file
		fi
	done
}


sync_in_primary_DBFS(){
	# In DBFS method, there is a folder dbfs in the domain, both in SOA and WLS, which is and must be different in each site.
	# Hence, it is excluded from the copy
	export exclude_list="--exclude 'dbfs' --exclude 'soampRebootEnv.sh' "
	export exclude_list="$exclude_list --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' "
	export exclude_list="$exclude_list --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp' "
        export exclude_list="$exclude_list --exclude 'servers/*/adr/diag/ofm/*/*/lck/*.lck' --exclude 'servers/*/adr/oracle-dfw-*/sampling/jvm_threads*' "
	export exclude_list="$exclude_list --exclude 'tmp' "
	export exclude_list="$exclude_list --exclude '/nodemanager' "
	
	export max_rsync_retries=4
	export dbfs_plog_file=$DBFS_MOUNT_PATH/last_primary_update_${date_label}.log
	export diff_file=$DBFS_MOUNT_PATH/last_primary_update_${date_label}_diff.log
	echo "rsync output to ${dbfs_plog_file} ..."

	ORIGIN_FOLDER="$DOMAIN_HOME/"
	DEST_FOLDER="$DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME"

	export rsync_command="rsync -avz --stats --modify-window=1 $exclude_list $ORIGIN_FOLDER  $DEST_FOLDER  > ${dbfs_plog_file}"
	eval $rsync_command
	stilldiff="true"
while [ $stilldiff == "true" ]
        do
        rsync_compare_command="rsync -niaHc ${exclude_list} $ORIGIN_FOLDER  $DEST_FOLDER --modify-window=1"
        eval $rsync_compare_command > $diff_file
        echo "Checksum comparison of source and target dir completed." >> $dbfs_plog_file
        compare_result=$(cat $diff_file | grep -v  '.d..t......' | grep -v  'log' | grep -v  'DAT' | wc -l)
        echo "$compare_result number of differences found" >> $dbfs_plog_file
        if [ $compare_result -gt 0 ]; then
                ((rsynccount=rsynccount+1))
                if [ "$rsynccount" -eq "$max_rsync_retries" ];then
                        stilldiff="false"
                        echo "Maximum number of retries reached" 2>&1 | tee -a $dbfs_plog_file
                        echo "******************WARNING:*********************************************************************" 2>&1 | tee -a $dbfs_plog_file
                        echo "Copy of config was retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a $dbfs_plog_file
			echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a $dbfs_plog_file
                        echo "This may be caused by logs and/or DAT files being modified by the source domain while performing the rsync operation." 2>&1 | tee -a $dbfs_plog_file
			echo "It is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a $dbfs_plog_file
			echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers" 2>&1 | tee -a $dbfs_plog_file
			echo "after running the config_replica.sh in the standby site." 2>&1 | tee -a $dbfs_plog_file
                        echo "************************************************************************************************" 2>&1 | tee -a $dbfs_plog_file

                else
                        stilldiff="true"
                        echo "Differences are: " >> $dbfs_plog_file
                        cat $diff_file >> $dbfs_plog_file
                        cat $diff_file |grep -v  '.d..t......'  |grep -v  'log' | awk '{print $2}' > ${diff_file}_pending
                        echo "Trying to rsync again the differences" >> $dbfs_plog_file
                        export sec_rsync_command="rsync $rsync_options --stats --modify-window=1 --files-from=${diff_file}_pending $ORIGIN_FOLDER  $DEST_FOLDER  >> $dbfs_plog_file"
                        echo "Rsyncing the pending files..." >> $dbfs_plog_file
                        eval $sec_rsync_command >> $dbfs_plog_file
                        echo "RSYNC RETRY NUMBER $rsynccount" >> $dbfs_plog_file
                fi
        else
                stilldiff="false"
                echo "Source and target directories are in sync. ALL GOOD!" 2>&1 | tee -a $dbfs_plog_file
        fi
done

	#rm -rf $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME/nodemanager #now added in the excludes
	echo "Rsync complete!"

}

sync_in_secondary(){
        echo ""
        echo "************** SYNC IN SECONDARY **********************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                sync_in_secondary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                sync_in_secondary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}


sync_in_secondary_RSYNC(){
        echo "Rsyncing from FSS mount to domain dir..."
        rm  -rf ${DOMAIN_HOME}/servers/*
        rsync -avz  --exclude 'tmp' ${COPY_FOLDER}/$WLS_DOMAIN_NAME/ ${DOMAIN_HOME}/
        echo $(date '+%d-%m-%Y-%H-%M-%S') > ${DOMAIN_HOME}/last_secondary_update.log
        echo "Rsync complete!"
}

sync_in_secondary_DBFS(){
        echo "Rsyncing from dbfs mount to domain dir..."
        rm  -rf ${DOMAIN_HOME}/servers/*
        rsync -avz  --exclude 'tmp' $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME/ ${DOMAIN_HOME}/
        echo $(date '+%d-%m-%Y-%H-%M-%S') > ${DOMAIN_HOME}/last_secondary_update.log
        echo "Rsync complete!"
	
}


replace_connect_info(){
        echo ""
        echo "************** REPLACE INSTANCE SPECIFIC DB CONNECT INFORMATION ***************************"
	cd ${DOMAIN_HOME}/config/
	echo "String for primary...................." ${REMOTE_JDBC_URL}
	echo "String for secondary.................." ${LOCAL_JDBC_URL}
	find . -name '*.xml' | xargs sed -i 's|'${REMOTE_JDBC_URL}'|'${LOCAL_JDBC_URL}'|gI'
	echo "Replacement complete!"

	# Uncomment this to update other datasources where the string is not exactly the same than in opss (i.e: they use other service name)
	#echo "Replacing instance specific scan name in datasources with differen url (i.e: different service name)..."
	#echo "-------------------------------------------------------------------------------------------------------"
	#cd ${DOMAIN_HOME}/config/jdbc/
	#echo "Db address for primary...................." $REMOTE_CONNECT_ADDRESS
	#echo "Db address for secondary.................." $LOCAL_CONNECT_ADDRESS
	#find . -name '*.xml' | xargs sed -i 's|'${REMOTE_CONNECT_ADDRESS}'|'${LOCAL_CONNECT_ADDRESS}'|g'
	#echo "Replacement complete!"

	if [ "${REMOTE_ONS_ADDRESS}" != "" ];then
	  echo "Replacing instance specific ONS node list in jdbc files..."
	  echo "-------------------------------------------------------------"
	  cd ${DOMAIN_HOME}/config/jdbc/
	  echo "String for current primary...................." $REMOTE_ONS_ADDRESS
	  echo "String for current secondary.................." $LOCAL_ONS_ADDRESS
	  find . -name '*.xml' | xargs sed -i 's|'${REMOTE_ONS_ADDRESS}'|'${LOCAL_ONS_ADDRESS}'|g'
	  echo "Replacement complete!"
	fi
	echo ""
}


post_sync_in_secondary(){
        echo ""
        echo "************** POST SYNC TASKS IN SECONDARY **********************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                post_sync_in_secondary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                post_sync_in_secondary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}

post_sync_in_secondary_RSYNC(){
	echo "nothing to do"
	# nothing to do
}

post_sync_in_secondary_DBFS(){
	# db_role has the value of the initial status of the standby database
	# if it was physical standby, we need to convert to physical standby again
	if [[ $db_role = *"PHYSICAL STANDBY"* ]]; then
		echo " Standby database was originally in PHYSICAL STANDBY mode"
		echo " Converting it to PHYSICAL STANDBY again..."
                export STANDBY_REQ_STATUS="physical standby"
		convert_standby
	elif [[ $db_role = *"SNAPSHOT STANDBY"* ]]; then
		echo " Standby database was originally in SNAPSHOT STANDBY mode"
		echo " Hence, NOT converting it to physical standby"
	fi

}




######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################


######################################################################################################################
# MAIN
######################################################################################################################
echo ""
echo "********************************Preparing Copy of configuration******************************"
echo "*** This script depends on the appropriate execution of the fmw_primary and fmw_standby   ***"
echo "*** scripts (or alternatively, the appropiate execution of the DRS tool).                 ***"
echo "*********************************************************************************************"
get_DR_method
get_variables
get_localdb_role
get_localdb_role_result=$?
if [ "$get_localdb_role_result" == 0 ];then
	if [[ $db_role = *PRIMARY* ]];then
		echo "This site has PRIMARY role. "
		echo "The script will copy data from domain directory to assistance folder (dbfs/FSS)."
		checks_in_primary
		sync_in_primary	
	elif [[ $db_role = *"PHYSICAL STANDBY"* ]] || [[ $db_role = *"SNAPSHOT STANDBY"* ]];then
                echo "This site has STANDBY role. "
		echo "The script will copy data from assistance folder (dbfs/FSS) to local domain directory and replace connect string."
		checks_in_secondary
		sync_in_secondary
		retrieve_remote_connect_info
		replace_connect_info
		post_sync_in_secondary
	else
	  	echo "Unable to identify the DB's role."
		echo $(date '+%d-%m-%Y-%H-%M-%S') > /u01/data/domains/$WLS_DOMAIN_NAME/last_failed_update.log
	fi

else
        echo "Invalid password. Check DB connection and credentials"
fi

echo "*******************************************Finished******************************************"

######################################################################################################################
# END OF MAIN
######################################################################################################################

