#!/bin/bash

## PaaS DR scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script should be executed in the PRIMARY Weblogic Administration server node
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
###         fmw_dr_setup_primary.sh DB_SYS_PASSWORD DR_METHOD [REMOTE_ADMIN_NODE_IP] [REMOTE_SSH_PRIV_KEYFILE]
###
### Where:
###	DB_SYS_PASSWORD:		The primary database SYS user's password
###	DR_METHOD:			The DR Method used. It should be set to:
###					- DBFS:		When using DBFS method. 
###							The domain config replication to secondary site is done via Data Guard replica.
###					- RSYNC: 	When using FSS with rsync method. 
###							The domain config replication to the secondary site will be done via rsync. This script assumes that 
###							you followed the steps described in the DR whitepaper to prepare the environment and the FSS is mounted in /fssmount.
###
###	REMOTE_ADMIN_NODE_IP:		[ONLY WHEN DR_METHOD IS RSYNC] 
###					This is the IP address of the secondary Weblogic Administration server node.
###					This IP needs to be reachable from this host. 
###					It is recommended to use Dynamic Routing Gateway to interconnect primary and secondary sites, hence you can provide the private IP.
###
###	REMOTE_SSH_PRIV_KEYFILE:	[ONLY WHEN DR_METHOD IS RSYNC] 
###					The complete path to the ssh private keyfile used to connect to secondary Weblogic Administration server node.
###					Example: /u01/install/myprivatekey.key


# Check that this is running by oracle
if [ "$(whoami)" != "oracle" ]; then
        echo "Script must be run as user: oracle"
        exit 1
fi

#export VERBOSE=true


######################################################################################################################
# INPUT PARAMETERS SECTION
######################################################################################################################

if [[ $# -ne 0 ]]; then
        export DR_METHOD=$2
        if  [[ $DR_METHOD = "DBFS" ]]; then
                if [[ $# -eq 2 ]]; then
                        export SYS_USER_PASSWORD=$1
                else
                        echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 2, got $#"
                        echo "Usage for DR_METHOD=DBFS:"
                        echo "      $0  SYS_USER_PASSWORD DR_METHOD "
                        echo "Example: "
                        echo "      $0 'acme1234#' 'DBFS' "
                        echo ""
                        exit 1
                fi

        elif [[ $DR_METHOD = "RSYNC" ]]; then
                if [[ $# -eq 4 ]]; then
                        export SYS_USER_PASSWORD=$1
                        export REMOTE_ADMIN_NODE_IP=$3
                        export REMOTE_KEYFILE=$4
                else
                        echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $1. Expected 4, got $#"
                        echo "Usage for DR_METHOD=RSYNC:"
                        echo "    $0  SYS_USER_PASSWORD DR_METHOD REMOTE_ADMIN_NODE_IP REMOTE_KEYFILE"
                        echo "Example:  "
                        echo "    $0  'acme1234#' 'RSYNC' '10.1.2.43' '/u01/install/KeyWithoutPassPhraseSOAMAA.ppk'"
                        echo ""
                        exit 1
                fi
        else
                echo ""
                echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $1"
		echo "Usage: "
		echo "	$0 SYS_USER_PASSWORD DR_METHOD [REMOTE_ADMIN_NODE_IP] [REMOTE_KEYFILE]"
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

	# Get the DB SYS password
        while true; do
                echo
                echo "(1) The primary database SYS user's password"
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

	# Get the DR_METHOD
	echo
	echo "(2) Enter the method that is going to be used for the DR setup"
	echo "    The DR Method should be set to:"
	echo "        - DBFS:  When using DBFS method. The domain config replication to secondary site is done via Data Guard replica."
	echo "        - RSYNC: When using FSS with rsync method. The domain config replication to the secondary site will be done via rsync."

	echo
	echo " Enter DR METHOD (DBFS or RSYNC): "

	read -r DR_METHOD
	
	if  [[ $DR_METHOD = "RSYNC" ]]; then
		# Get the Remote WLS Administration server node IP
		echo
		echo "(3) Enter the IP address of the secondary Weblogic Administration server node."
		echo "    Note: this IP needs to be reachable from this host." 
		echo "	  Recommended to use DRG to interconnect primary and secondary sites, hence you can provide the private IP"
		echo
		echo " Enter secondary Weblogic Administration server node IP: "
		read -r REMOTE_ADMIN_NODE_IP

		# Get the ssh private keyfile for Weblogic Administration server node IP
		echo
		echo "(4) Enter the complete path to the ssh private keyfile used to connect to secondary Weblogic Administration server node."
                echo "    Example: /u01/install/myprivatekey.ppk"
		echo "    This is needed for the remote rsync commands"
		echo
		echo " Enter path to the private ssh keyfile: "

		read -r REMOTE_KEYFILE
	fi
fi

######################################################################################################################
# END OF VARIABLES SECTION
######################################################################################################################




######################################################################################################################
# FUNCTIONS SECTION
######################################################################################################################

######################################################################################################################
############################### FUNCTIONS TO GET VARIABLES ###########################################################
######################################################################################################################

get_DR_method(){
        echo ""
        echo "************** GET DR TOPOLOGY METHOD ********************************************"
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

	# Primary JDBC URL is obtained in the same way regardless RAC IS USED or NOT 
        export A_JDBC_URL=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
	
        if [[ ${VERBOSE} = "true" ]]; then
		echo "COMMON VARIABLES for dbfs and rsync methods:"
		echo " DOMAIN_HOME..........................." $DOMAIN_HOME
		echo " DATASOURCE_NAME......................." $DATASOURCE_NAME
		echo " A_JDBC_URL............................" $A_JDBC_URL
	fi

	#OTHER VARIABLES THAT DEPEND ON THE METHOD
	if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                get_variables_in_primary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                get_variables_in_primary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
	
}

get_variables_in_primary_RSYNC(){
	#PREDEFINED VARIABLES FOR RSYNC METHOD
	export FSS_MOUNT=/fssmount
	export COPY_FOLDER=${FSS_MOUNT}/domain_config_copy

        if [[ ${VERBOSE} = "true" ]]; then
		echo "SPECIFIC VARIABLES FOR RSYNC METHOD:"
		echo " FSS_MOUNT............................" ${FSS_MOUNT}
		echo " COPY_FOLDER.........................." ${COPY_FOLDER}
		echo " REMOTE_ADMIN_NODE_IP................." ${REMOTE_ADMIN_NODE_IP}
		echo " REMOTE_KEYFILE......................." ${REMOTE_KEYFILE}
	fi

        # When the method is RSYNC, we cannot use the db client to gather any value, hence, gathering using wlst
	check_if_RAC_nosqlplus
	gather_primary_variables_from_DS
	get_CBD_values_nosqlplus
	
}

get_variables_in_primary_DBFS(){
	# PREDEFINED VARIABLES FOR DBFS METHOD
	export DBFS_MOUNT_SCRIPT=${DOMAIN_HOME}/dbfs/dbfsMount.sh
	#Variables obtained from the dbfs mount script
	export ORACLE_HOME=$(cat $DBFS_MOUNT_SCRIPT | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
	export DBFS_MOUNT=$(cat $DBFS_MOUNT_SCRIPT | grep "MOUNT_PATH=" | head -n 1 | awk -F "=" '{print $2}')
	# IF SOAMP
	if [[ ${PAAS} = "SOAMP" ]]; then
		export DBFS_MOUNT_IO=$(cat $DBFS_MOUNT_SCRIPT | grep "MOUNT_PATH_DIRECTIO=" | head -n 1 | awk -F "=" '{print $2}')
		export DBFS_MOUNT_PATH=$DBFS_MOUNT/share
		export DBFS_TNS_ALIAS='ORCL'
	# IF WLS OCI
	elif [[ ${PAAS} = "WLSMP" ]]; then
		export DBFS_MOUNT_PATH=$DBFS_MOUNT/dbfsdir
	fi
	export TNS_ADMIN=$(cat $DBFS_MOUNT_SCRIPT | grep "TNS_ADMIN=" | head -n 1 | awk -F "=" '{print $2}')
	#Variables with fixed values
	export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
	export PATH=$PATH:$ORACLE_HOME/bin
	export SYS_USERNAME=sys
	export CONNECT_TIMEOUT=10
	export RETRY_COUNT=10
	export RETRY_DELAY=10

        # NOTE than when the method is DBFS, we can use db client, hence, gathering using sqlplus
	check_if_RAC
	gather_primary_variables_from_DS
	get_CDB_values
}

check_if_RAC(){
	echo ""
	echo "Checking if RAC (sqlplus) ............................."

	export cluster_database=$(
	echo "set feed off
	set pages 0
	select value from v\$parameter where name='cluster_database';
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba"
	)
	if  [[ $cluster_database = *TRUE* ]]; then
		echo " Database is a RAC database"
		export RAC=true
	elif  [[ $cluster_database = *FALSE* ]]; then
		echo " Database is NOT a RAC database"
		export RAC=false
	else
		echo " ERROR: Cannot determine if the database is a RAC DB or not"
		exit 1
	fi
        echo ""
}

check_if_RAC_nosqlplus(){
        echo ""
        echo "Checking if RAC (wlst) ................................"

        export jdbc_url="jdbc:oracle:thin:@"${A_JDBC_URL}
        export username="sys as sysdba"
        export password=${SYS_USER_PASSWORD}
        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/check_if_rac.py
        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/check_if_rac.py
        echo "username = \"$username\" " >> /tmp/check_if_rac.py
        echo "password = \"$password\" " >> /tmp/check_if_rac.py
        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/check_if_rac.py
        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/check_if_rac.py
        echo "cursor = conn.cursor(1)" >> /tmp/check_if_rac.py
        echo "cursor.execute(\"select value from v\$parameter where name='cluster_database'\")" >> /tmp/check_if_rac.py
        echo "print cursor.fetchone()" >> /tmp/check_if_rac.py
        export cluster_database=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/check_if_rac.py | tail -1)

        if  [[ $cluster_database = *TRUE* ]]; then
                echo " Database is a RAC database"
                export RAC=true
        elif  [[ $cluster_database = *FALSE* ]]; then
                echo " Database is NOT a RAC database"
                export RAC=false
        else
                echo " ERROR: Cannot determine if the database is a RAC DB or not"
                exit 1
        fi
        echo ""
}


gather_primary_variables_from_DS() {
        echo ""
        echo "Getting variables from the datasource ..............."
	# The gathering of these variables is different depending if RAC is used or not
	if [ $RAC = "true" ]; then
		echo " RAC database is used"
		export PDB_NAME=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'SERVICE_NAME=' '{print $2}' | awk -F ')' '{print $1}' | awk -F '.' '{print $1}')
		export A_PRIV_HN=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'HOST=' '{print $2}' | awk -F ')' '{print $1}')
		export A_PORT=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'PORT=' '{print $2}' | awk -F ')' '{print $1}')
		export PDB_SERVICE_PRIMARY=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'SERVICE_NAME=' '{print $2}' | awk -F ')' '{print $1}')

	else
		echo " Single instance database is used"
		export PDB_NAME=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@' '{print $2}'| awk -F ':' '{print $2}' | awk -F '/' '{print $2}' | awk -F '.' '{print $1}')
		export A_PRIV_HN=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@//' '{print $2}' |awk -F '</url>' '{print $1}'| awk -F ':' '{print $1}')
		export A_PORT=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@' '{print $2}' | awk -F ':' '{print $2}' | awk -F '/' '{print $1}')
		export PDB_SERVICE_PRIMARY=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@//' '{print $2}' |awk -F '</url>' '{print $1}' | awk -F '/' '{print $2}' )
	fi
	# Checks to make sure these variables are gathered
	if [[ ${PDB_NAME} = "" ]] ; then
		echo " ERROR: Cannot determine the PDB Name from the datasource"
	        exit 1
	fi
	if [[ ${A_PRIV_HN} = "" ]] ; then
		echo " ERROR: Cannot determine the database hostname from the datasource"
		exit 1
	fi
	if [[ ${A_PORT} = "" ]] ; then
		echo " ERROR: Cannot determine the database port from the datasource"
		exit 1
	fi
	if [[ ${PDB_SERVICE_PRIMARY} = "" ]] ; then
		echo " ERROR: Cannot determine the primary PDB service name from the datasource"
		exit 1
	fi


        if [[ ${VERBOSE} = "true" ]]; then
		echo " PDB Name.............................." $PDB_NAME
		echo " Primary private Hostname.............." $A_PRIV_HN
		echo " Primary TNS Listener Port............." $A_PORT
		echo " Primary PDB Service..................." $PDB_SERVICE_PRIMARY
	fi
        echo ""
}

get_CDB_values() {
	echo ""
        echo "Getting CDB specific values from the primary DB (sqlplus)............"

	export A_DBNM=$(
	echo "set feed off
	set pages 0
	select DB_UNIQUE_NAME from V\$DATABASE;
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${A_DBNM} = "" ]] ; then
		echo " ERROR: Cannot determine the primary DB unique name from the database"
		exit 1
	fi

	export A_DB_DOMAIN=$(
	echo "set feed off
	set pages 0
	select value from v\$parameter where name='db_domain';
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${A_DB_DOMAIN} = "" ]] ; then
		echo " ERROR: Cannot determine the primary DB domain from the database"
		exit 1
	fi


	export B_DBNM=$(
	echo "set feed off
	set pages 0
	select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DEST_ROLE like '%STANDBY%';
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${B_DBNM} = "" ]] ; then
		echo " ERROR: Cannot determine the standby db unique name from the database"
		exit 1
	fi

    	# We obtain the alias to secondary remote database from the LOCAL database
	export remote_alias_string=$(
	echo "set feed off
	set pages 0
	set lines 10000
	SELECT DBMS_TNS.RESOLVE_TNSNAME ('"${B_DBNM}"') from dual;
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${remote_alias_string} = "" ]] ; then
		echo " ERROR: Cannot determine the standby tns string"
		exit 1
	fi
	
	# Removing additional CID entry at the end of the string
	remote_alias_string=$(echo $remote_alias_string  | awk -F '\\(CID=' '{print $1}')
	# Adding required closing parenthesis
	remote_alias_string=${remote_alias_string}"))"
	
        if [[ ${VERBOSE} = "true" ]]; then
	        echo " Primary DB UNIQUE NAME.............." $A_DBNM
	        echo " Primary DB DOMAIN .................." $A_DB_DOMAIN
	        echo " Secondary DB UNIQUE NAME............" $B_DBNM
	        echo " Remote tns alias string ............" $remote_alias_string		
	fi
        echo ""

}

get_CBD_values_nosqlplus(){
        echo ""
        echo "Getting CDB specific values from the primary DB (wlst) ............."

        export jdbc_url="jdbc:oracle:thin:@"${A_JDBC_URL}
        export username="sys as sysdba"
        export password=${SYS_USER_PASSWORD}

        #get primary CDB name
        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_CDB_values.py
        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_CDB_values.py
        echo "username = \"$username\" " >> /tmp/get_CDB_values.py
        echo "password = \"$password\" " >> /tmp/get_CDB_values.py
        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_CDB_values.py
        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_CDB_values.py
        echo "cursor = conn.cursor(1)" >> /tmp/get_CDB_values.py
        echo "cursor.execute(\"select DB_UNIQUE_NAME from V\$DATABASE\")" >> /tmp/get_CDB_values.py
        echo "print cursor.fetchone()" >> /tmp/get_CDB_values.py
        result=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_CDB_values.py | tail -1)
       	export A_DBNM=$(echo $result | awk -F \' '{print $2}')
	if [[ ${A_DBNM} = "" ]] ; then
		echo " ERROR: Cannot determine the primary DB unique name from the database"
		exit 1
	fi


        #get primary CDB domain name
        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_CDB_values.py
        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_CDB_values.py
        echo "username = \"$username\" " >> /tmp/get_CDB_values.py
        echo "password = \"$password\" " >> /tmp/get_CDB_values.py
        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_CDB_values.py
        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_CDB_values.py
        echo "cursor = conn.cursor(1)" >> /tmp/get_CDB_values.py
        echo "cursor.execute(\"select value from v\$parameter where name='db_domain'\")" >> /tmp/get_CDB_values.py
        echo "print cursor.fetchone()" >> /tmp/get_CDB_values.py
        result=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_CDB_values.py | tail -1)
        export A_DB_DOMAIN=$(echo $result | awk -F \' '{print $2}')
	if [[ ${A_DB_DOMAIN} = "" ]] ; then
                echo " ERROR: Cannot determine the primary DB domain from the database"
                exit 1
        fi

        #get secondary CDB namw
        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_CDB_values.py
        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_CDB_values.py
        echo "username = \"$username\" " >> /tmp/get_CDB_values.py
        echo "password = \"$password\" " >> /tmp/get_CDB_values.py
        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_CDB_values.py
        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_CDB_values.py
        echo "cursor = conn.cursor(1)" >> /tmp/get_CDB_values.py
        echo "cursor.execute(\"select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DEST_ROLE like '%STANDBY%'\")" >> /tmp/get_CDB_values.py
        echo "print cursor.fetchone()" >> /tmp/get_CDB_values.py
        result=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_CDB_values.py | tail -1)
        export B_DBNM=$(echo $result | awk -F \' '{print $2}')
	if [[ ${B_DBNM} = "" ]] ; then
		echo " ERROR: Cannot determine the standby DB unique name from the database"
		exit 1
	fi


        #get secondary CDB alias (to get service name and domain name)
        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_CDB_values.py
        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_CDB_values.py
        echo "username = \"$username\" " >> /tmp/get_CDB_values.py
        echo "password = \"$password\" " >> /tmp/get_CDB_values.py
        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_CDB_values.py
        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_CDB_values.py
        echo "cursor = conn.cursor(1)" >> /tmp/get_CDB_values.py
        echo "cursor.execute(\"SELECT DBMS_TNS.RESOLVE_TNSNAME ('${B_DBNM}') from dual\")" >> /tmp/get_CDB_values.py
        echo "print cursor.fetchone()" >> /tmp/get_CDB_values.py
        result=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_CDB_values.py | tail -1)
        export remote_alias_string=$(echo $result | awk -F \' '{print $2}')
	if [[ ${remote_alias_string} = "" ]] ; then
		echo " ERROR: Cannot determine the standby tns string"
		exit 1
        fi
        # Removing additional CID entry at the end of the string
        remote_alias_string=$(echo $remote_alias_string  | awk -F '\\(CID=' '{print $1}')
        # Adding required closing parenthesis
        remote_alias_string=${remote_alias_string}"))"

        if [[ ${VERBOSE} = "true" ]]; then
		echo " Primary DB UNIQUE NAME................" $A_DBNM
	        echo " Primary DB DOMAIN ...................." $A_DB_DOMAIN
	        echo " Secondary DB UNIQUE NAME.............." $B_DBNM
		echo " Remote tns alias string .............." $remote_alias_string
	fi
        echo ""

}


######################################################################################################################
############################## FUNCITONS TO CHECK ####################################################################
######################################################################################################################

checks_in_primary(){
        echo ""
        echo "************** CHECKS IN PRIMARY ***********************************************"
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
        export result=$(ssh -o ConnectTimeout=100 -o StrictHostKeyChecking=no -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
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
	echo " Checking DBFS mount point................"
	if mountpoint -q $DBFS_MOUNT; then
            echo "	DBFS mount at $DBFS_MOUNT is ready!"
	else
            echo "	Error: DBFS Mount point $DBFS_MOUNT not available. Will try to mount again..."
            ${DBFS_MOUNT_SCRIPT}
            sleep 10
            if mountpoint -q $DBFS_MOUNT; then
            	echo "	Mount at $DBFS_MOUNT is ready."
            else
            	echo "	Error: DBFS Mount point $DBFS_MOUNT not available even after another try to mount. Check your DBFS set up."
		exit 1
            fi
    fi
}



######################################################################################################################
###################################### FUNCTIONS TO PREPARE PRIMARY ##################################################
######################################################################################################################


prepare_primary(){
        echo ""
        echo "************** PREPARE PRIMARY ************************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                prepare_primary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                prepare_primary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}

prepare_primary_RSYNC(){
	export CDB_SERVICE_FILE=/u01/data/domains/local_CDB_jdbcurl.nodelete
	echo "Creating $CDB_SERVICE_FILE with local CDB service content for future usage...."
        echo "${A_PRIV_HN}:${A_PORT}/${A_DBNM}.${A_DB_DOMAIN}" > $CDB_SERVICE_FILE
}

prepare_primary_DBFS(){
	configure_tns_alias
        # Create a file with local CDB url, for the config replica
        export CDB_SERVICE_FILE=/u01/data/domains/local_CDB_jdbcurl.nodelete
        echo "Creating $CDB_SERVICE_FILE with local CDB service  for future usage................"
        echo "${A_PRIV_HN}:${A_PORT}/${A_DBNM}.${A_DB_DOMAIN}" > $CDB_SERVICE_FILE
	# In adition for DBFS method, this is created as in previous versions, 
	# used by dbfscopy script when method is dbfs (for dgmgrl conversions)
        echo "Creating ${DOMAIN_HOME}/dbfs/localdb.log with local CDB unique name for future usage...."
	echo $A_DBNM >  ${DOMAIN_HOME}/dbfs/localdb.log

	# In WLSMP not needed to re-configure dbfs because it is configured with dbfs_root script
	# In SOAMP, following additional steps are needed:
	if [[ ${PAAS} = "SOAMP" ]]; then
		get_dbfs_info
		save_dbfs_info
		recreate_dbfs_config
	fi
}

configure_tns_alias() {
        echo "Configuring tnsnames.ora to add alias to CDBs ............"
	mv ${TNS_ADMIN}/tnsnames.ora ${TNS_ADMIN}/tnsnames.ora_backup_$date_label
	cat >> ${TNS_ADMIN}/tnsnames.ora <<EOF
${A_DBNM} =
(DESCRIPTION =
  (SDU=65536)
  (RECV_BUF_SIZE=10485760)
  (SEND_BUF_SIZE=10485760)
  (ADDRESS = (PROTOCOL = TCP)(HOST = ${A_PRIV_HN})(PORT =${A_PORT}))
  (CONNECT_DATA =
   (SERVER = DEDICATED)
   (SERVICE_NAME = ${A_DBNM}.${A_DB_DOMAIN})
   )
)

${B_DBNM} = ${remote_alias_string}

${PDB_NAME} =
(DESCRIPTION =
 (CONNECT_TIMEOUT= ${CONNECT_TIMEOUT})(RETRY_COUNT=${RETRY_COUNT}) (RETRY_DELAY=${RETRY_DELAY})
 (ADDRESS = (PROTOCOL = TCP)(HOST = ${A_PRIV_HN})(PORT = ${A_PORT}))
 (CONNECT_DATA =
  (SERVER = DEDICATED)
  (SERVICE_NAME = ${PDB_SERVICE_PRIMARY})
 )
)
EOF
}

######### Following are specific SOAMP specific functions
get_dbfs_info(){
	# ONLY FOR SOA
	echo "Getting DBFS info ......................................."
	# Gathering schema prefix
	export PRIMARY_SCHEMA_PREFIX=$(grep OPSS ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | tr -d "<value>" |sed "s/_OPSS\///g")
	if [[ ${VERBOSE} = "true" ]]; then
		echo " Primary Schema prefix ...................." $PRIMARY_SCHEMA_PREFIX
	fi	
	
	# Gathering DBFS schema password
	export PWDENC=$(grep "<password-encrypted>" ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '<password-encrypted>' '{print $2}'  | awk -F '</password-encrypted>' '{print $1}')
	echo "domain='${DOMAIN_HOME}'" > /tmp/pret.py
	echo "service=weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain)" >>/tmp/pret.py
	echo "encryption=weblogic.security.internal.encryption.ClearOrEncryptedService(service)" >>/tmp/pret.py
	echo "print encryption.decrypt('${PWDENC}')"  >>/tmp/pret.py
	export DBFS_SCHEMA_PASSWORD=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/pret.py | tail -1)
	rm /tmp/pret.py
	
}
	
save_dbfs_info(){
	# ONLY FOR SOA
	# This info will be used in standby to recreate dbfs mount artifacts
	export ENCRYPTED_DBFS_SCHEMA_PASSWORD=$(
        echo  "set feed off
        set pages 0
        select DBMS_CRYPTO.encrypt(UTL_RAW.CAST_TO_RAW('$DBFS_SCHEMA_PASSWORD'), 4353 /* = dbms_crypto.DES_CBC_PKCS5 */, UTL_RAW.CAST_TO_RAW ('$SYS_USER_PASSWORD')) from dual;
        exit
        "  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba"
        )

	echo "Saving DBFS Information..................................."
	echo "set feed off
	set feedback off
	set pages 0
	set echo off
	set errorlogging off
	SET SERVEROUTPUT OFF
	Drop table DBFS_INFO;
	set errorlogging on
	SET SERVEROUTPUT ON
	CREATE TABLE DBFS_INFO  (DBFS_PREFIX VARCHAR(50), DBFS_PASSWORD VARCHAR(50));
	INSERT INTO DBFS_INFO (DBFS_PREFIX, DBFS_PASSWORD) VALUES('$PRIMARY_SCHEMA_PREFIX','$ENCRYPTED_DBFS_SCHEMA_PASSWORD');
	exit
	"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@${A_JDBC_URL} "as sysdba" > /dev/null
	echo "DBFS Information saved!"
}

recreate_dbfs_config(){
	# ONLY FOR SOA
	echo "Recreating DBFS artifacts.................................."	
	unset ORACLE_HOME
	echo "Unmounting current dbfs mounts..."
	result1=$(fusermount -u $DBFS_MOUNT_IO 2>&1)
	result2=$(fusermount -u $DBFS_MOUNT 2>&1)
	echo $result1
	echo $result2

	if [[ -z "$result1"  && -z "$result2" ]] ; then
		# The umount was success
        	echo "Unmounted!"
	elif [[ $result1 = *"Device or resource busy"* || $result2 = *"Device or resource busy"* ]]; then
		# Warn and exit
        	echo "ERROR. At least one of the DBFS mounts cannot be unmounted because it is in use."
        	echo "Please check and close any process using the mounts, and unmount them manually:"
        	echo "  fusermount -u $DBFS_MOUNT_IO"
        	echo "  fusermount -u $DBFS_MOUNT "
        	echo "And then rerun DRS"
		# before exiting, restoring the tnsnames.ora
		# to prevent issues in next run due to partial update of the dbfs config
		cp ${TNS_ADMIN}/tnsnames.ora_backup_$date_label ${TNS_ADMIN}/tnsnames.ora
        	exit 1
	elif [[ $result1 = *"not found in /etc/mtab"* || $result2 = *"not found in /etc/mtab"* ]]; then
        	# In this case at least one was already umounted. ok and continue
        	echo "Unmounted!"
	fi

	mv ${TNS_ADMIN}/wallet/ ${TNS_ADMIN}/wallet_backup_$date_label

	echo "Creating new wallet..."
	printf ${SYS_USER_PASSWORD}'\n'${SYS_USER_PASSWORD}'\n' | ${MIDDLEWARE_HOME}/oracle_common/bin/mkstore -wrl ${DOMAIN_HOME}/dbfs/wallet/ -create > /dev/null
	echo "Wallet created!"
	echo "Adding credential to the wallet..."
	export add_cred_command="-createCredential ${PDB_NAME} ${PRIMARY_SCHEMA_PREFIX}_DBFS ${DBFS_SCHEMA_PASSWORD}"
	printf ${SYS_USER_PASSWORD}'\n' | ${MIDDLEWARE_HOME}/oracle_common/bin/mkstore -wrl ${DOMAIN_HOME}/dbfs/wallet/ ${add_cred_command} > /dev/null
	echo "New credential added!"

	echo "Mounting DBFS points again..."
	export ORACLE_HOME=$(cat $DBFS_MOUNT_SCRIPT | grep "ORACLE_HOME=" | head -n 1 | awk -F "=" '{print $2}')
	${ORACLE_HOME}/bin/dbfs_client -o wallet /@${PDB_NAME} -o direct_io ${DBFS_MOUNT_IO}
	${ORACLE_HOME}/bin/dbfs_client -o wallet /@${PDB_NAME} ${DBFS_MOUNT}
	cp ${DBFS_MOUNT_SCRIPT}  ${DBFS_MOUNT_SCRIPT}_backup_$date_label
	sed -i "s/${DBFS_TNS_ALIAS}/${PDB_NAME}/g" ${DBFS_MOUNT_SCRIPT}
	# Add the fusemount line if it does not exists
	linecount=$(grep -c "fusermount -u" ${DBFS_MOUNT_SCRIPT})
	if [ $linecount -eq 0 ]; then
		export add_str_dbfs="fusermount -u $DBFS_MOUNT_IO;fusermount -u $DBFS_MOUNT;"
		export dbfs_line=$(awk '/direct_io/{ print NR; exit }' ${DBFS_MOUNT_SCRIPT})
		sed -i.bkp "$dbfs_line i$add_str_dbfs" ${DBFS_MOUNT_SCRIPT} 
	fi
}
##end of SOAMP specific functions

######################################################################################################################
############################### FUNCTIONS TO SYNC IN PRIMARY #########################################################
######################################################################################################################

sync_in_primary(){
        echo ""
        echo "************** SYNC IN PRIMARY ************************************************"
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
	export exclude_list="--exclude 'dbfs/tnsnames.ora' --exclude 'soampRebootEnv.sh' --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp'  --exclude 'servers/*/adr/diag/ofm/*/*/lck/*.lck' --exclude 'servers/*/adr/oracle-dfw-*/sampling/jvm_threads*' --exclude 'tmp'"
	
	# First, a copy to local FSS mount folder
	echo ""
	echo "----------- Rsyncing from local domain to local FSS folder ---------------"
	echo ""
	export rsync_log_file=${COPY_FOLDER}/last_primary_update_local_${date_label}.log
	export diff_file=${COPY_FOLDER}/last_primary_update_local_${date_label}_diff.log
	echo "Local rsync output to ${rsync_log_file} ...."
	export local_rsync_command="rsync -avz --stats --modify-window=1 $exclude_list ${DOMAIN_HOME}/  ${COPY_FOLDER}/${WLS_DOMAIN_NAME}"
	eval $local_rsync_command >> ${rsync_log_file}
	
	export local_rsync_compare_command="rsync -niaHc ${exclude_list} ${DOMAIN_HOME}/ ${COPY_FOLDER}/$WLS_DOMAIN_NAME/ --modify-window=1"
	export local_sec_rsync_command="rsync --stats --modify-window=1 --files-from=${diff_file}_pending ${DOMAIN_HOME}/ ${COPY_FOLDER}/$WLS_DOMAIN_NAME "
        export rsync_compare_command=${local_rsync_compare_command}
	export sec_rsync_command=${local_sec_rsync_command}
	compare_rsync_diffs
	
	rm -rf ${COPY_FOLDER}/$WLS_DOMAIN_NAME/nodemanager
	echo ""
        echo "----------- Local rsync complete -----------------------------------------"
	echo ""
	# Then, copy from the local FSS mount folder to remote node(no risk of in-flight changes)
        echo "----------- Rsyncing from local FSS folder to remote site... --------------"
        export rsync_log_file=${COPY_FOLDER}/last_primary_update_remote_${date_label}.log
        export diff_file=${COPY_FOLDER}/last_primary_update_remote_${date_label}_diff.log
	echo "Remote rsync output to ${rsync_log_file} ...."
        # We need to do sudo to oracle because if not, the files are created with the user opc
        export remote_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_KEYFILE}\" -avz --stats --modify-window=1 $exclude_list ${COPY_FOLDER}/${WLS_DOMAIN_NAME}/ opc@${REMOTE_ADMIN_NODE_IP}:${COPY_FOLDER}/${WLS_DOMAIN_NAME}"
        eval $remote_rsync_command >> $rsync_log_file

        export remote_rsync_compare_command="rsync --rsync-path \"sudo -u oracle rsync\"  -e \"ssh -i ${REMOTE_KEYFILE}\" -niaHc ${exclude_list}  ${COPY_FOLDER}/${WLS_DOMAIN_NAME}/ opc@${REMOTE_ADMIN_NODE_IP}:${COPY_FOLDER}/${WLS_DOMAIN_NAME} --modify-window=1"
        export remote_sec_rsync_command="rsync --rsync-path \"sudo -u oracle rsync\" -e \"ssh -i ${REMOTE_KEYFILE}\" --stats --modify-window=1 --files-from=${diff_file}_pending ${COPY_FOLDER}/${WLS_DOMAIN_NAME}/ opc@${REMOTE_ADMIN_NODE_IP}:${COPY_FOLDER}/${WLS_DOMAIN_NAME} "
        export rsync_compare_command=${remote_rsync_compare_command}
        export sec_rsync_command=${remote_sec_rsync_command}
        compare_rsync_diffs
        echo ""
        echo "------------ Remote rsync complete-------------------------------------------"
	echo ""
}

compare_rsync_diffs(){
        export max_rsync_retries=4
	stilldiff="true"
	while [ $stilldiff == "true" ]
	do
		eval $rsync_compare_command > $diff_file  # DEINFE THIS COMMAN BEFORE CALLING THIS FUNCTION
		echo "Checksum comparison of source and target dir completed." >> $rsync_log_file
		compare_result=$(cat $diff_file | grep -v  '.d..t......' | grep -v  'log' | grep -v  'DAT' | wc -l)
		echo "$compare_result number of differences found" >> $rsync_log_file
		if [ $compare_result -gt 0 ]; then
			((rsynccount=rsynccount+1))
			if [ "$rsynccount" -eq "$max_rsync_retries" ];then
				stilldiff="false"
				echo "Maximum number of retries reached" 2>&1 | tee -a $rsync_log_file
				echo "******************************WARNING:***********************************************" 2>&1 | tee -a $rsync_log_file
				echo "Copy of config was retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a $rsync_log_file
				echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a $rsync_log_file
				echo "This may be caused by logs and/or DAT files being modified by the source domain while performing the rsync operation." 2>&1 | tee -a $rsync_log_file
				echo "You can continue with the DR setup." 2>&1 | tee -a $rsync_log_file
				echo "Once DR setup is completed (after running DR setup scripts in the standby servers)," 2>&1 | tee -a $rsync_log_file
				echo "it is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a $rsync_log_file
				echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers." 2>&1 | tee -a $rsync_log_file
				echo "*************************************************************************************" 2>&1 | tee -a $rsync_log_file

			else
				stilldiff="true"
				echo "Differences are: " >> $rsync_log_file
				cat $diff_file >> $rsync_log_file
				cat $diff_file |grep -v  '.d..t......'  |grep -v  'log' | awk '{print $2}' > ${diff_file}_pending
				echo "Trying to rsync again the differences" >> $rsync_log_file
				echo "Rsyncing the pending files..." >> $rsync_log_file
				eval $sec_rsync_command >> $rsync_log_file  # dEFINE this command before calling this function
				echo "RSYNC RETRY NUMBER $rsynccount" >> $rsync_log_file
			fi
		else
			stilldiff="false"
			echo "Source and target directories are in sync. ALL GOOD!" 2>&1 | tee -a $rsync_log_file
		fi
	done
}

sync_in_primary_DBFS(){
	echo "Rsyncing from domain dir to dbfs mount..."
	export exclude_list="--exclude 'dbfs' --exclude 'soampRebootEnv.sh' --exclude 'servers/*/data/nodemanager/*.lck' --exclude 'servers/*/data/nodemanager/*.pid' --exclude 'servers/*/data/nodemanager/*.state' --exclude 'servers/*/tmp'  --exclude 'servers/*/adr/diag/ofm/*/*/lck/*.lck' --exclude 'servers/*/adr/oracle-dfw-*/sampling/jvm_threads*' --exclude 'tmp'"
        # whitout checking rsync
	#export rsync_command="rsync -avz --stats --modify-window=1 $exclude_list ${DOMAIN_HOME}/  ${DBFS_MOUNT_PATH}/${WLS_DOMAIN_NAME} "
        #eval  $rsync_command

	# ADDED FOR CHECKING and comparing 
	export date_label=$(date '+%d-%m-%Y-%H-%M-%S')
	export max_rsync_retries=4
	export dbfs_plog_file=$DBFS_MOUNT_PATH/last_primary_update_${date_label}.log
	echo "rsync output to ${dbfs_plog_file} ..."
	export diff_file=$DBFS_MOUNT_PATH/last_primary_update_${date_label}_diff.log
	export rsync_command="rsync -avz --stats --modify-window=1 $exclude_list ${DOMAIN_HOME}/  $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME  > ${dbfs_plog_file}"
	eval $rsync_command 

	stilldiff="true"
	while [ $stilldiff == "true" ]
	do
		rsync_compare_command="rsync -niaHc ${exclude_list} ${DOMAIN_HOME}/  ${DBFS_MOUNT_PATH}/$WLS_DOMAIN_NAME/ --modify-window=1"
		eval $rsync_compare_command > $diff_file
		echo "Checksum comparison of source and target dir completed." >> $dbfs_plog_file
		compare_result=$(cat $diff_file | grep -v  '.d..t......' | grep -v  'log' | grep -v  'DAT' | wc -l)
		echo "$compare_result number of differences found" >> $dbfs_plog_file
		if [ $compare_result -gt 0 ]; then
			((rsynccount=rsynccount+1))
			if [ "$rsynccount" -eq "$max_rsync_retries" ];then
				stilldiff="false"
			
				echo "Maximum number of retries reached" 2>&1 | tee -a $dbfs_plog_file
				echo "******************************WARNING:***********************************************" 2>&1 | tee -a $dbfs_plog_file
                                echo "Copy of config was retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a $dbfs_plog_file
                                echo "source and target directories beyond the explicitly excluded files." 2>&1 | tee -a $dbfs_plog_file
                                echo "This may be caused by logs and/or DAT files being modified by the source domain while performing the rsync operation." 2>&1 | tee -a $dbfs_plog_file
				echo "You can continue with the DR setup." 2>&1 | tee -a $dbfs_plog_file
                                echo "Once DR setup is completed (after running dr setup scripts in the standby servers)," 2>&1 | tee -a $dbfs_plog_file
				echo "it is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a $dbfs_plog_file
                                echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers" 2>&1 | tee -a $dbfs_plog_file
                                echo "*************************************************************************************" 2>&1 | tee -a $dbfs_plog_file

				echo "******************************WARNING:***********************************************" 2>&1 | tee -a $dbfs_plog_file
				echo "Copy of config was retried $max_rsync_retries and there are still differences between" 2>&1 | tee -a $dbfs_plog_file
				echo "source and target directories (besides the explicitly excluded files)." 2>&1 | tee -a $dbfs_plog_file
				echo "This may be caused by logs and/or DAT files being modified by the source domain while performing the rsync operation." 2>&1 | tee -a $dbfs_plog_file
				echo "You can continue with the DR setup." 2>&1 | tee -a $dbfs_plog_file
				echo "Once DR setup is completed (after running DR setup scripts in the standby servers)," 2>&1 | tee -a $dbfs_plog_file
				echo "it is recommended to verify that the copied domain files are valid in your secondary location." 2>&1 | tee -a $dbfs_plog_file
				echo "To perform this verification, convert the standby database to snapshot and start the secondary WLS domain servers." 2>&1 | tee -a $dbfs_plog_file
				echo "*************************************************************************************" 2>&1 | tee -a $dbfs_plog_file

			else
				stilldiff="true"
				echo "Differences are: " >> $dbfs_plog_file
				cat $diff_file >> $dbfs_plog_file
				cat $diff_file |grep -v  '.d..t......'  |grep -v  'log' | awk '{print $2}' > ${diff_file}_pending
				echo "Trying to rsync again the differences" >> $dbfs_plog_file
				export sec_rsync_command="rsync $rsync_options --stats --modify-window=1 --files-from=${diff_file}_pending ${DOMAIN_HOME}/  $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME  >> $dbfs_plog_file"
				echo "Rsyncing the pending files..." >> $dbfs_plog_file
				eval $sec_rsync_command >> $dbfs_plog_file
				echo "RSYNC RETRY NUMBER $rsynccount" >> $dbfs_plog_file
			fi
		else
			stilldiff="false"
			echo "Source and target directories are in sync. ALL GOOD!" 2>&1 | tee -a $dbfs_plog_file
		fi
	done

	rm -rf $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME/nodemanager
	echo "Rsyncing complete!"
	echo $(date '+%d-%m-%Y-%H-%M-%S') > $DBFS_MOUNT_PATH/last_primary_update.log

}


######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################



######################################################################################################################
# MAIN
######################################################################################################################
echo ""
echo "******************************* FMW DR setup script in PRIMARY site *************************"
echo "*** This script prepares primary and copies the primary domain to secondary site ************"
echo "*** Before running this script make sure that you have followed the steps described in the **"
echo "*** DR whitepaper to prepare the environment for the specific DR method you are using.    ***"
echo "*********************************************************************************************"
echo ""

get_DR_method
get_variables
checks_in_primary
prepare_primary
# we repeat checks again before syncing
checks_in_primary
sync_in_primary	

echo "*********************************************************************************************"
echo "*******************************************Finished******************************************"
echo "*********************************************************************************************"

######################################################################################################################
# END OF MAIN
######################################################################################################################

