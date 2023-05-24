#!/bin/bash

## fmwadb_config_replica.sh script version 2.0
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script is used to replicate configuration between sites.
### This script should be executed in the WLS Administration Node (either primary or standby).
### Typically it would be croned/scheduled to replicate configuration between a primary and standby FMW-ADB system.
### This script checks the current role of the local database to determine if it is running in primary or standby site.
### When it runs in PRIMARY site: 
###	it copies the domain config from primary domain to local assistance folder (FSS), 
##	and then to the secondary site assistance folder (via FSS/rsync).
### When it runs in STANDBY site: 
###	it copies the domain config from the secondary assistance folder (FSS) to the secondary domain, and makes the required replacements.
###
### Since it is expected to be "croned" all variables need to be customized in the script itself (i.e. not passed as arguments)
### Usage:
###
###	./fmwadb_config_replica.sh 
###	The following varibles (below) need to be edited/added in the script itself before executing the script
###
###	REMOTE_WLSADMIN_NODE_IP:
###		Peer and remote Weblogic Administration server node's IP. This is the IP of the node hostine the WLS Administration Server
###		in the peer site. It needs to be reachable from the local node. It is recommended to connect to the remote private ip of the node
###		via Dynamic Routing Gateway.
###
###	REMOTE_SSH_PRIV_KEYFILE:
###		The private ssh keyfile to connect to remote Weblogic Administration server node.
###
###	TENANCY_OCID:
###		This is the OCID of the tenancy where the ADB resides. It can be obtained from the OCI UI
###		Refer to https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/contactingsupport_topic-Finding_Your_Tenancy_OCID_Oracle_Cloud_Identifier.htm
###
###	USER_OCID:		
###		This is the OCID of the user owning the ADB instance. It can be obtained from the OCI UI.
###		Refer to https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/contactingsupport_topic-Finding_Your_Tenancy_OCID_Oracle_Cloud_Identifier.htm
###
###	PRIVATE_KEY:
### 		Path to the private PEM format key for this user
### 		Refer to https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm for details
###
###	ADB_OCID:
###		This is the OCID of the ADB being inspected. The ADB OCID can be obtained from the ADB screen in OCI UI
###
###     WALLET_DIR:
###		This is the directory for the local ADB' wallet (unzip the wallet downloded from the OCI console)
###		This directory should contain at least a tnsnames.ora, keystore.jks and truststore.jks files.
###
###    ENC_WALLET_PASSWORD:
###		This is the WLS ENCRYPTED encarnation of the password provided when the wallet was downloaded from the ADB OCI UI.
###		If the wallet is the initial one created by WLS/SOA/FMW during provisioning WLS, the password can be obtained with the
###		following command:
###                                     SOA     python /opt/scripts/atp_db_util.py generate-atp-wallet-password
###                                     WLS     python3 /opt/scripts/atp_db_util.py generate-atp-wallet-password
###		To encyrpt the password (whether the one provided in the OCI console or the one used during provionining) you can use the
###		fmw_enc_pwd.sh script (./fmw_enc_pwd.sh UNENC_WALLET_PASSWORD) The obtained string is the one to be used bellow for the
###		ENC_WALLET_PASSWORD variable
###   
###   FSS_MOUNT:
###		This is the OCI File Storage Mounted directory that will be used to stage the WLS domain configuration

###############################################################################################################
################## BEGIN CUSTOMIZED PARAMETERS SECTION ########################################################
###############################################################################################################
# The following parmeters are obligatory
export REMOTE_WLSADMIN_NODE_IP='10.2.225.66'
export REMOTE_SSH_PRIV_KEYFILE='/u01/install/my_keys/KeyWithoutPassPhraseSOAMAA.priv'
export TENANCY_OCID='ocid1.tenancy.oc1..aaaaaaaa7dkeohv7arjwvdgobyqml2vefxxrokon3f2bxo6z6e2odqxsklgq'
export USER_OCID='ocid1.user.oc1..aaaaaaaa77pn6uke4zyxeumfxv4tfyveensu5doteepq6d7jqaubes3fsq4q'
export PRIVATE_KEY='/u01/install/my_keys/oracleidentitycloudservice_iratxe.etxebarria-02-28-08-31.pem'
export WALLET_DIR='/u01/install/wallets/ADBD1_ashburn'
export ENC_WALLET_PASSWORD='{AES256}uLDRSaCrg4th+3HeK/aCNbN67Szw7xOxWrKQFcIxGp0UTkV77siabhc3TYrk2rd95c03uTn3XTfvqaXnNuts4Q=='
export LOCAL_ADB_OCID="ocid1.autonomousdatabase.oc1.iad.anuwcljrj4y3nwqamjjo3epmwjdwsl3bbbjtksn4y5co7vxd7hovdrotirnq"
export FSS_MOUNT="/u01/share"

###############################################################################################################
################## END OF CUSTOMIZED PARAMATERS SECTION #######################################################
###############################################################################################################

export date_label=$(date +%H_%M_%S-%d-%m-%y)
export copy_folder=${FSS_MOUNT}/domain_config_copy
export datasource_name=opss-datasource-jdbc.xml
export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
export remote_datasource_file="${copy_folder}/$WLS_DOMAIN_NAME/config/jdbc/${datasource_name}"
export exec_path=$(dirname "$0")
export log_file=$FSS_MOUNT/config_replica_log_${date_label}.log
export dec_wallet_pwd=null

######################################################################################################################
# FUNCTIONS
######################################################################################################################

get_PaaS_type(){
	# Determining if WLSMP or SOAMP using the hostname naming
	hostnm=$(hostname)
	if [ -d /u01/app/oracle/suite ]; then
		export PaaS=SOAMP
	elif [[ $hostnm == *"-wls-"* ]]; then
		export PaaS=WLSMP
	else
		echo "Error. PaaS service unknown" | tee -a  $log_file
		exit 1
	fi
}

get_variables(){
	echo ""  | tee -a  $log_file
	echo "************** CHECKING CONFIGURATION *****************************************************"  | tee -a  $log_file
	get_PaaS_type
	# COMMON VARIABLES
	if [ -z "${DOMAIN_HOME}" ];then
		echo "\$DOMAIN_HOME is empty. This variable must be predefined in the oracle user's .bashrc." | tee -a $log_file
		echo "Example: export DOMAIN_HOME=/u01/data/domains/my_domain"  | tee -a  $log_file
		exit 1
	else
		export WLS_DOMAIN_NAME=$(echo ${DOMAIN_HOME} |awk -F '/u01/data/domains/' '{print $2}')
	fi

        if [ -f "${datasource_file}" ]; then
                echo "Found ${datasource_name}: $datasource_file "  | tee -a  $log_file
        else
                echo "The datasource ${datasource_name} does not exist"  | tee -a  $log_file
                echo "Provide an alternative datasource name"  | tee -a  $log_file
                exit
        fi

	if [[ ${VERBOSE} = "true" ]]; then
                echo "VARIABLES VALUES:"  | tee -a  $log_file
                echo " PaaS type.........................." ${PaaS}  | tee -a  $log_file
                echo " Datasource name...................." ${datasource_name}  | tee -a  $log_file
                echo " WLS Domain Home...................." ${DOMAIN_HOME}  | tee -a  $log_file
                echo " WLS Domain Name...................." ${WLS_DOMAIN_NAME}  | tee -a  $log_file
                echo " FSS mount.........................." ${FSS_MOUNT}  | tee -a  $log_file
                echo " Stage folder......................." ${copy_folder}  | tee -a  $log_file
                echo " Remote WLS Admin node's IP........." ${REMOTE_WLSADMIN_NODE_IP}  | tee -a  $log_file
                echo " SSH private key file..............." ${REMOTE_SSH_PRIV_KEYFILE}  | tee -a  $log_file

	fi

}

get_localdb_role(){
	echo ""  | tee -a  $log_file
        echo "************** GET LOCAL DB ROLE *************************************************"
	export count=0;
	export top=3;
	while [ $count -lt  $top ]; do
		export db_role=$($exec_path/fmwadb_rest_api_listabds.sh $TENANCY_OCID $USER_OCID $PRIVATE_KEY $LOCAL_ADB_OCID | grep ROLE | awk -F: '{print $2}') 
		echo "The role of the database is: ${db_role}"  | tee -a  $log_file
		if  [[ ${db_role} = *PRIMARY* ]] || [[ ${db_role} = *STANDBY* ]]  || [[ ${db_role} = *null* ]]; then
			echo "Role check performed. Proceeding..."  | tee -a  $log_file
			count=3
			return 0
		else
			echo "Unable to obtain valid DB infromation through REST API"  | tee -a  $log_file
			count=$(($count+1));
			if [ $count -eq 3 ]; then
				echo "Maximum number of attempts exceeded."  | tee -a  $log_file
				echo "Review the information provided to query the DB status though REST API."  | tee -a  $log_file
                        	echo "Check the USER's OCID, TENANCY's OCID and ADB's OCID."  | tee -a  $log_file
			return 1
			fi
		fi
	done
	echo ""  | tee -a  $log_file
}

get_localrc_mode(){
        echo ""  | tee -a  $log_file
        echo "************** GET REFRESHABLE CLONE INFO *************************************************"  | tee -a  $log_file
        export count=0;
        export top=3;
        while [ $count -lt  $top ]; do
		export pdb_mode=$($exec_path/fmwadb_rest_api_listabds.sh $TENANCY_OCID $USER_OCID $PRIVATE_KEY $LOCAL_ADB_OCID | grep refreshableMode| awk -F: '{print $2}')
                echo "The refreshable mode of the database is: ${pdb_mode}"  | tee -a  $log_file
                if  [[ ${pdb_mode} = *MANUAL* ]]; then
                	count=3
                   	return 0
		elif [[ ${pdb_mode} = *null* ]]; then
			count=3
			echo "Determined that the DB used is NOT a refreshable clone..."  | tee -a  $log_file
			return 0
                else
                	echo "Unkown value returned for refreshableMode."  | tee -a  $log_file
			count=$(($count+1));
                   	if [ $count -eq 3 ]; then
                        	echo "Maximum number of attempts exceeded, review you login to the DB."  | tee -a  $log_file
                        return 1
                   fi
                fi
        done
        echo ""  | tee -a  $log_file
}

checks_in_primary_RSYNC(){
        # Check connectivity to remote Weblogic Administration server node and show its hostname
        echo " Checking ssh connectivity to remote Weblogic Administration server node...."  | tee -a  $log_file
        export result=$(ssh -o ConnectTimeout=100 -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_WLSADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
        if [ $result == "OK" ];then
                echo "    Connectivity to ${REMOTE_WLSADMIN_NODE_IP} is OK"  | tee -a  $log_file
                export remote_admin_hostname=$(ssh -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_WLSADMIN_NODE_IP} 'hostname --fqdn')
                echo "    remote_admin_hostname......" ${remote_admin_hostname}  | tee -a  $log_file
        else
                echo "    Error: Failed to connect to ${REMOTE_WLSADMIN_NODE_IP}"  | tee -a  $log_file
                exit 1
        fi

        # Check local mount is ready
        echo " Checking local FSS ${FSS_MOUNT} folder readiness..."  | tee -a  $log_file
        if mountpoint -q ${FSS_MOUNT}; then
                echo "    Mount at ${FSS_MOUNT} is ready!"  | tee -a  $log_file
                echo "    Will use ${copy_folder} to stage the domain configuration."  | tee -a  $log_file
                mkdir -p  ${copy_folder}
        else
                echo "    Error: local FSS mount not available at ${FSS_MOUNT}"  | tee -a  $log_file
                exit 1
        fi

        # Check remote mount is ready
        echo " Checking remote FSS mount folder readiness........"  | tee -a  $log_file
	if ssh -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_WLSADMIN_NODE_IP} "mountpoint -q ${FSS_MOUNT}";then
		echo "    Remote mount at ${REMOTE_WLSADMIN_NODE_IP}:${FSS_MOUNT} is ready!" | tee -a  $log_file
		echo "    Will use ${REMOTE_WLSADMIN_NODE_IP}:${copy_folder} to stage the domain configuration in remote site." | tee -a  $log_file
		ssh -i $REMOTE_SSH_PRIV_KEYFILE opc@${REMOTE_WLSADMIN_NODE_IP} "sudo su - oracle -c \"mkdir -p  ${copy_folder}\" " | tee -a  $log_file
        else
                echo "    Error: remote FSS mount not ready at ${REMOTE_WLSADMIN_NODE_IP}:${FSS_MOUNT}."  | tee -a  $log_file
                exit 1
        fi
}

checks_in_secondary_RSYNC(){
        echo " Checking local FSS mount folder readiness........"  | tee -a  $log_file
        echo "     The FSS is expected to be mounted in ${FSS_MOUNT}"  | tee -a  $log_file
        echo "     The folder for the copy of the domain is expected to be ${copy_folder}"  | tee -a  $log_file

	if mountpoint -q ${FSS_MOUNT}; then
		echo "Mount at ${FSS_MOUNT} is ready!" | tee -a  $log_file
		if [ -d "${copy_folder}" ];then
			echo "Local folder ${copy_folder} exists." | tee -a  $log_file
		else
			echo "Error: Local folder ${copy_folder} does not exists."  | tee -a  $log_file
			exit 1
		fi
        else
                echo "Error: local FSS mount not available at ${FSS_MOUNT}" | tee -a  $log_file
		exit 1
        fi
}

sync_in_primary(){
	$exec_path/fmwadb_dr_prim.sh $REMOTE_WLSADMIN_NODE_IP $REMOTE_SSH_PRIV_KEYFILE $FSS_MOUNT | tee -a  $log_file
}


decrypt_wallet_password(){
	echo "domain='${DOMAIN_HOME}'" > /tmp/pret.py
	echo "service=weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain)" >>/tmp/pret.py
	echo "encryption=weblogic.security.internal.encryption.ClearOrEncryptedService(service)" >>/tmp/pret.py
	echo "print encryption.decrypt('${ENC_WALLET_PASSWORD}')"  >>/tmp/pret.py
	export dec_wallet_pwd=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/pret.py | tail -1)
	rm /tmp/pret.py
}

sync_in_secondary(){
        decrypt_wallet_password
	#Now with backup option
        $exec_path/fmwadb_dr_stby.sh $WALLET_DIR $dec_wallet_pwd $FSS_MOUNT nobackup | tee -a  $log_file
}


######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################


######################################################################################################################
# MAIN
######################################################################################################################
echo "**********************************EXECUTING CONFIGURATION REPLICATION**********************************" | tee -a  $log_file
echo "Information from this operation will be stored at $log_file"
get_variables
get_localdb_role
get_localdb_role_result=$?
if [ "$get_localdb_role_result" == 0 ];then
	if [[ $db_role = *PRIMARY* ]];then
		echo "This site has PRIMARY role. "  | tee -a  $log_file
		echo "The script will copy data from domain directory to assistance folder (FSS)."  | tee -a  $log_file
		echo "This is a standard primary, proceeding..."  | tee -a  $log_file
		checks_in_primary_RSYNC
		sync_in_primary
	elif [[ $db_role = *STANDBY* ]];then
                echo "This site has STANDBY role. "  | tee -a  $log_file
		echo "The script will copy data from assistance folder (FSS) to local domain directory and replace connect string."  | tee -a  $log_file
		checks_in_secondary_RSYNC
		sync_in_secondary
	elif [[ $db_role = *null* ]];then
		get_localrc_mode
                get_localrc_mode_result=$?
                if [ "$get_localrc_mode_result" == 0 ];then
			if  [[ ${pdb_mode} = *MANUAL* ]]; then
        			echo "The datasource provided is pointing to a refreshable clone."  | tee -a  $log_file
	                        echo "Config replication should be set based on primary and standby, not on refreshable clones."  | tee -a  $log_file
        	                echo "To test a configuration with a Refreshable clone, first replicate configuration to a standby"  | tee -a  $log_file
                	        echo "and THEN change datasources from standby to refreshable clone."  | tee -a  $log_file
	                elif [[ ${pdb_mode} = *null* ]]; then
                        	echo "Determined that the DB used is NOT a refreshable clone."  | tee -a  $log_file
				echo "You are using a Database that is not a refreshable clone nor part of a Data Guard configuration."  | tee -a  $log_file
				echo "To test a configuration with a third database, first replicate configuration to a standby."  | tee -a  $log_file
                                echo "and THEN change datasoruces to point to that third database."  | tee -a  $log_file
			fi
			echo "Provide a datasource that points either to a primary or to a stanby DB."  | tee -a  $log_file
		else
	  		echo "Unable to identify the ADBS REFRESHABLE CLONE MODE."  | tee -a  $log_file
			echo $(date '+%d-%m-%Y-%H-%M-%S') > $DOMAIN_HOME/last_failed_update.log
		fi
		exit
	else
        	echo "Invalid ADB DATA GUARD ROLE. Check DB status"  | tee -a  $log_file
        	echo $(date '+%d-%m-%Y-%H-%M-%S') > $DOMAIN_HOME/last_failed_update.log
		exit
	fi
else
	echo "Unable to identify the ADB DATA GUARD ROLE."  | tee -a  $log_file
        echo $(date '+%d-%m-%Y-%H-%M-%S') > $DOMAIN_HOME/last_failed_update.log 
        exit

fi

echo "***********************************************Finished***********************************************"  | tee -a  $log_file

######################################################################################################################
# END OF MAIN
######################################################################################################################

