#!/bin/bash

## dg_setup_scripts version 2.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


### Description: Script to prepare the primary system for Data Guard
### 
# CONSIDERATIONS:
# 1.-BEFORE RUNNING THIS SCRIPT, EDIT THE PROPERTY FILE DG_properties.ini WITH THE APPROPRIATE VALUES
# 2.-THIS SCRIPT SHOULD BE EXECUTED BY THE "oracle" USER IN THE PRIMARY DATABASE NODE
# 3.-THIS SCRIPT PREPARES THE PRIMARY SYSTEM FOR A DATAGUARD CONFIGURATION THAT WILL BE CREATED FROM THE STANDBY DATABASE NODE
# 4.-THIS SCRIPT CREATE 2 TAR FILES (for password file and TDE wallet) THAT NEED TO BE COPIED TO THE STANDBY DATABASE NODE(S)
# 5.-IF RAC, RUN FIRST IN THE NODE1, AND THEN IN THE NODE2.
# 6.-THIS SCRIPT DOES NOT PERFORM OS CHANGES LIKE net.core.rmem_max and net.core.wmem_max or MTU. REFER TO THE MAA PAPERS TO SET THESE 
#   (IT IS A BEST PRACTICE TO ADJUST net.core.rmem_max and net.core.wmem_max FOR OPTIMUM REDO TRASNPORT)

########################################################################
# Load environment specific variables
########################################################################
if [ -f DG_properties.ini ]; then
        . DG_properties.ini
else
        echo "ERROR: DG_properties.ini not found"
        exit 1
fi

#Check that this is running by oracle user
if [ "$(whoami)" != "${ORACLE_OSUSER}" ]; then
        echo "Script must be run as user: ${ORACLE_OSUSER}"
        exit 1
fi


########################################################################
#Variables with fixed or dynamically obtained values
########################################################################
export dt=$(date +%Y-%m-%d-%H_%M_%S)
. $HOME/.bashrc

# For multidb envs
if [ ! -z "${A_CUSTOM_ENV_FILE}" ] || [ -f ${A_CUSTOM_ENV_FILE} ]; then
        . ${A_CUSTOM_ENV_FILE}
fi

if [ -z "$ORACLE_HOME" ]; then
	echo "Error: the ORACLE_HOME variable is not defined"
	exit 1
fi

if [ -f "${ORACLE_HOME}/bin/orabasehome" ]; then
	# Since 18c, base home may be used. In 21c, that is the only option.
	# So getting the TNS admin and default password file folders dynamically.
	export TNS_ADMIN=$($ORACLE_HOME/bin/orabasehome)/network/admin
	export PASSWORD_FILE_FOLDER=$($ORACLE_HOME/bin/orabaseconfig)/dbs
else
	# For versions below 18c
	export TNS_ADMIN=$ORACLE_HOME/network/admin
	export PASSWORD_FILE_FOLDER=$ORACLE_HOME/dbs
fi

export DB_NAME=$(
echo "set feed off
set pages 0
select value from V\$PARAMETER where NAME='db_name';
exit
"  | sqlplus -s / as sysdba
)

export PWFILE_ASM_LOC=$A_FILE_DEST/$A_DBNM/PASSWORD

#######################################################################
# Functions
########################################################################

check_rac_node(){
        if  [[ $RAC = "YES" ]]; then
		echo ""
		echo "This is a RAC"
		echo "Is this the first node of the primary RAC? [y/n]:"
		read -r -s  FIRST_NODE
		if  [[ $FIRST_NODE = "y" ]]; then
			echo "This is the first node of the primary RAC"
			echo ""
		elif [[ $FIRST_NODE = "n" ]]; then
			echo "This is the second node of the primary RAC"
			echo ""
		else
			echo "Error: invalid value provided. Please answer y/n"
			exit 1
		fi
	fi
}

show_databases_info(){
	if  [[ $RAC = "NO" ]]; then
		show_databases_info_single
	elif [[ $RAC = "YES" ]]; then
		show_databases_info_rac
	else
		echo "Error: provide a valid value for RAC input property. It must be set to YES or NO"
		exit 1
	fi
}

show_databases_info_single(){
	echo ""
	echo "DB NAME................................" $DB_NAME
	echo ""
	echo "**************************PRIMARY SYTEM INFORMATION GATHERED**************************************"
	echo "Primary DB UNIQUE NAME................." $A_DBNM
	echo "Primary DB Port is....................." $A_PORT
	echo "Primary DB Host is....................." $A_DB_IP
        echo "Primary DB Service is.................." $A_SERVICE
        echo "**************************************************************************************************"


	if [ -z "$A_DBNM" ] || [ -z "$DB_NAME" ] || [ -z "$A_PORT" ] || [ -z "$A_DB_IP" ] || [ -z "$A_SERVICE" ]; then
                echo "Error: one of the values  is null"
                exit 1
        fi

	echo ""
        echo "**************************SECONDARY SYTEM INFORMATION GATHERED*************************************"
        echo "Secondary DB UNIQUE NAME................." $B_DBNM
        echo "Secondary DB Port is....................." $B_PORT
        echo "Secondary DB Host is....................." $B_DB_IP
        echo "Secondary DB service name ..............." $B_SERVICE
        echo "***************************************************************************************************"
        if [ -z "$B_DBNM" ] || [ -z "$DB_NAME" ] || [ -z "$B_PORT" ] || [ -z "$B_DB_IP" ] || [ -z "$B_SERVICE" ] ; then
                echo "Error: one of the values  is null"
                exit 1
        fi
	
	echo ""
        echo "**************************OTHER VARIABLES***********************************************************"
	echo ""
	echo "TDE_LOC..................................." $TDE_LOC
	echo "OUTPUT_WALLET_TAR........................." $OUTPUT_WALLET_TAR
        echo "CREATE_PASSWORD_FILE......................" $CREATE_PASSWORD_FILE
	echo "OUTPUT_PASWORD_TAR........................" $OUTPUT_PASWORD_TAR
	echo ""
	echo "ORACLE_HOME..............................." $ORACLE_HOME
	echo "TNS_ADMIN................................." $TNS_ADMIN
	echo "Default PASSWORD_FILE_FOLDER.............." $PASSWORD_FILE_FOLDER
	echo "PASSWORD_FILE_IN_ASM......................" $PASSWORD_FILE_IN_ASM
	echo "***************************************************************************************************"

}

show_databases_info_rac(){
        echo ""
	echo "**************************PRIMARY SYTEM INFORMATION GATHERED****************************************"
	echo "DB NAME................................" $DB_NAME
        echo "Primary DB UNIQUE NAME................." $A_DBNM
        echo "Primary DB Port is....................." $A_PORT
        echo "Primary DB Service is.................." $A_SERVICE
        echo "Primary scan IPs are .................." $A_SCAN_IP1, $A_SCAN_IP2, $A_SCAN_IP3
	echo "Primary scan address is ..............." $A_SCAN_ADDRESS
        if [ -z "$A_DBNM" ] || [ -z "$DB_NAME" ] || [ -z "$A_PORT" ] || [ -z "$A_SCAN_IP1" ] || [ -z "$A_SCAN_ADDRESS" ] ; then
                echo "Error: one of the values  is null"
                exit 1
        fi

	
	echo ""
	echo "**************************SECONDARY SYTEM INFORMATION GATHERED**************************************"
        echo "Secondary DB UNIQUE NAME................." $B_DBNM
        echo "Secondary DB Port is....................." $B_PORT
        echo "Secondary DB service name ..............." $B_SERVICE
        echo "Secondary DB scan IPs are ..............." $B_SCAN_IP1, $B_SCAN_IP2, $B_SCAN_IP3
        echo "Secondary DB  scan address is ..........." $B_SCAN_ADDRESS
        if [ -z "$B_DBNM" ] || [ -z "$DB_NAME" ] || [ -z "$B_PORT" ] || [ -z "$B_SCAN_IP1" ] || [ -z "$B_SCAN_ADDRESS" ] ; then
                echo "Error: one of the values  is null"
                exit 1
        fi

	echo ""
        echo "**************************OTHER VARIABLES***********************************************************"i
        echo ""
        echo "TDE_LOC..................................." $TDE_LOC
        echo "OUTPUT_WALLET_TAR........................." $OUTPUT_WALLET_TAR
        echo "CREATE_PASSWORD_FILE......................" $CREATE_PASSWORD_FILE
        echo "OUTPUT_PASWORD_TAR........................" $OUTPUT_PASWORD_TAR
        echo ""
        echo "ORACLE_HOME..............................." $ORACLE_HOME
        echo "TNS_ADMIN................................." $TNS_ADMIN
        echo "Default PASSWORD_FILE_FOLDER.............." $PASSWORD_FILE_FOLDER
        echo "PASSWORD_FILE_IN_ASM......................" $PASSWORD_FILE_IN_ASM
        echo "***************************************************************************************************"
        echo ""

}

retrieve_sys_password(){
        if  [[ $RAC = "NO" ]]; then
                PRIMARY_CONNECT_ADDRESS=$A_DB_IP:$A_PORT/$A_SERVICE
        elif [[ $RAC = "YES" ]]; then
                PRIMARY_CONNECT_ADDRESS=$A_SCAN_ADDRESS:$A_PORT/$A_SERVICE
        else
                echo "Error: provide a valid value for RAC input property. It must be set to YES or NO"
                exit 1
        fi

	export count=0;
	export top=3;
	while [ $count -lt  $top ]; do
		echo ""
		echo "Enter the database SYS password: "
		read -r -s  SYS_USER_PASSWORD
		export db_type=$(
		echo "set feed off
		set pages 0
		select database_role from v\$database;
		exit
		"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@$PRIMARY_CONNECT_ADDRESS as sysdba
		)
		if  [[ $db_type = *PRIMARY* ]]; then
			echo "Sys password is valid. Proceeding..."
			count=3
		else
			echo "Invalid password or incorrect DB status";
			echo "Check that you can connect to the DB and that it is in Data Guard PRIMARY role."
			count=$(($count+1));
			if [ $count -eq 3 ]; then
	        		echo "Error: Maximum number of attempts exceeded. Check DB connection and credentials"
				exit 1
			fi
		fi
	done
}


create_password_file(){
        if  [[ $CREATE_PASSWORD_FILE = "YES" ]]; then
		echo ""
		if [ -f "${PASSWORD_FILE_FOLDER}/orapw${DB_NAME}" ]; then
			cp ${PASSWORD_FILE_FOLDER}/orapw${DB_NAME} ${PASSWORD_FILE_FOLDER}/orapw${DB_NAME}.${dt}
		fi
		echo "Creating new password file ...."
		if  [[ $PASSWORD_FILE_IN_ASM = "YES" || $RAC = "YES" ]]; then
			PWFILE=${PWFILE_ASM_LOC}/orapw${DB_NAME}
			$ORACLE_HOME/bin/orapwd file=${PWFILE} password=${SYS_USER_PASSWORD} dbuniquename=${A_DBNM} force=y
		else 
			PWFILE=${PASSWORD_FILE_FOLDER}/orapw${DB_NAME}
			$ORACLE_HOME/bin/orapwd file=${PWFILE} password=${SYS_USER_PASSWORD}  force=y
		fi
                echo "New password file ${PWFILE} created!"
		srvctl modify database -db ${A_DBNM} -pwfile ${PWFILE}
	else
		echo ""
                echo "Skipping password file creation.."
	fi
	
		
}

create_password_tar(){
	echo ""
	echo "Creating output password file tar in ${OUTPUT_PASWORD_TAR} ..."
	if  [[ $PASSWORD_FILE_IN_ASM = "YES" || $RAC = "YES" ]]; then
		echo ""
		echo "---------------------- WARNING -----------------------------------------------------------------------------------------"
		echo "When password file is in ASM, the tar cannot be created with this script"
		echo "Please run the script \"create_pw_tar_from_asm_root.sh\" with root user in order to create the tar of the password file "
		echo "------------------------------------------------------------------------------------------------------------------------"
	else
	        if [ -z "${PASSWORD_FILE_FOLDER}/orapw${DB_NAME}" ]; then
        	        echo "Error: password file ${PASSWORD_FILE_FOLDER}/orapw${DB_NAME} not found"
			exit 1
        	else
			cd $PASSWORD_FILE_FOLDER
                	tar -czf ${OUTPUT_PASWORD_TAR} orapw${DB_NAME}
	                echo "Password file tar created!"
		fi
        fi

}

create_wallet_tar(){
	echo ""
        if [ -z "$TDE_LOC" ]; then
                echo "TDE_LOC not provided, no output tar will be created. This is expected only if TDE is not used."
                echo "If TDE is used (recommended), verify the input parameters."
        else
                echo "Creating wallet tar in ${OUTPUT_WALLET_TAR} ..."
                cd $TDE_LOC
                tar -czf ${OUTPUT_WALLET_TAR} ewallet.p12 cwallet.sso
                echo "Wallet tar created!"
        fi
}


add_net_encryption(){
        #Add only if "SQLNET.ENCRYPTION_CLIENT=REQUIRED" or "SQLNET.ENCRYPTION_CLIENT=requested" are not already
        linecount1=$(grep -i "SQLNET.ENCRYPTION_CLIENT" $TNS_ADMIN/sqlnet.ora | grep -ci required )
        linecount2=$(grep -i "SQLNET.ENCRYPTION_CLIENT" $TNS_ADMIN/sqlnet.ora | grep -ci requested )
        if [[ $linecount1 -eq 0 && $linecount2 -eq 0 ]]; then
                echo ""
                echo "Adding SQLNET encryption parameters to $TNS_ADMIN/sqlnet.ora ..."
                cp $TNS_ADMIN/sqlnet.ora $TNS_ADMIN/sqlnet.ora.${dt}
                cat >> $TNS_ADMIN/sqlnet.ora <<EOF
SQLNET.ENCRYPTION_CLIENT = requested
SQLNET.ENCRYPTION_TYPES_CLIENT = (AES256, AES192, AES128)
EOF
        echo "SQLNET encryption parameters added!"
        else
                echo ""
                echo "SQLNET encryption parameters already set in $TNS_ADMIN/sqlnet.ora "
        fi
}

configure_tns_alias(){
        if  [[ $RAC = "NO" ]]; then
                configure_tns_alias_single
        elif [[ $RAC = "YES" ]]; then
                configure_tns_alias_rac
        else
                echo "Error: provide a valid value for RAC input property. It must be set to YES or NO"
                exit 1
        fi


}

configure_tns_alias_single(){
        echo ""
        echo "Configuring TNS alias in $TNS_ADMIN/tnsnames.ora ..."
        cp $TNS_ADMIN/tnsnames.ora $TNS_ADMIN/tnsnames.ora.${dt}
        cat >> $TNS_ADMIN/tnsnames.ora <<EOF
${A_DBNM} =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${A_DB_IP})(PORT =${A_PORT}))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${A_SERVICE})
    )
  )
${B_DBNM} =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${B_DB_IP})(PORT =${B_PORT}))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${B_SERVICE})
    )
  )
EOF
        echo "TNS alias configured!"
}


configure_tns_alias_rac(){
        echo ""
        echo "Configuring TNS alias in $TNS_ADMIN/tnsnames.ora ..."
        cp $TNS_ADMIN/tnsnames.ora $TNS_ADMIN/tnsnames.ora.${dt}
        cat >> $TNS_ADMIN/tnsnames.ora <<EOF
${A_DBNM} =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS_LIST=
    (LOAD_BALANCE=on)
    (FAILOVER=on)
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${A_SCAN_IP1})(PORT = 1521))
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${A_SCAN_IP2})(PORT = 1521))
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${A_SCAN_IP3})(PORT = 1521)))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${A_SERVICE})
    )
  )
${B_DBNM} =
 (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS_LIST=
    (LOAD_BALANCE=on)
    (FAILOVER=on)
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${B_SCAN_IP1})(PORT = 1521))
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${B_SCAN_IP2})(PORT = 1521))
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${B_SCAN_IP3})(PORT = 1521)))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${B_SERVICE})
    )
   )

EOF
        echo "TNS alias configured!"
}


check_connectivity(){
	echo ""
	echo "Checking connectivity...."
	export tnsping_primresult=$(
	tnsping ${A_DBNM}
	)
	export tnsping_secresult=$(
	tnsping ${B_DBNM}
	)

	if [[ $tnsping_primresult = *OK* ]]; then
	        echo "Primary database listener reachable on alias"
	else
        	echo "Primary database cannot be reached using TNS alias. Either connectivty issues or errors in tnsnames"
	        echo "Check that the listener is up in primary and that you have the correct config in tnsames"
	fi

	if [[ $tnsping_secresult = *OK* ]]; then
	        echo "Remote Standby database listener reachable on alias"
	else
        	echo "Remote Standby database cannot be reached using TNS alias. Either connectivty issues or errors in tnsnames"
        	echo "Check that the listener is up in standby and that you have the correct config in tnsames"
		echo "NOTE: this is an expected error if the standby database/listener has not yet been configured"
	fi

	if [[ $tnsping_primresult = *OK* ]] && [[ $tnsping_secresult = *OK* ]]; then
        	echo "All good for tns connections!"
	else
		echo ""
        	echo "Issues in connection"
	fi
}



echo "**************************************************************************************************"
echo "********************************Preparing Primary DB for Data Guard*******************************"
echo "**************************************************************************************************"
echo ""
check_rac_node
show_databases_info
retrieve_sys_password
add_net_encryption
configure_tns_alias
check_connectivity

if  [[ $RAC = "YES" ]] && [[ $FIRST_NODE = "n" ]]; then
	echo ""
	echo "This is a RAC and the script is running in the second node of the RAC. Some steps are skipped."
else
	# In case of a RAC, these steps are performed only in the first node.
	# If not a RAC, these steps are performed always.
	create_wallet_tar
	create_password_file
	create_password_tar
fi

echo ""
echo "**************************************************************************************************"
echo "********************************Primary Database Prepared for DR**********************************"
echo "**************************************************************************************************"
