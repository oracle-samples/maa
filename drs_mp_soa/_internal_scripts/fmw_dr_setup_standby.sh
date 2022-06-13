#!/bin/bash

## PaaS DR scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
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
###         fmw_dr_setup_standby_standby.sh       (NOTE: User will be prompted for all values)
###
### Non-interactive usage:
###         fmw_dr_setup_standby_standby.sh  A_DB_IP  A_PORT  PDB_SERVICE_PRIMARY  SYS_DB_PASSWORD  DR_METHOD
###         fmw_dr_setup_standby_standby.sh  '129.146.117.58' '1521' 'soapdb.sub19281336420.soacsdrvcn.oraclevcn.com' "my_sysdba_password" 'DBFS'
###
### Where:
###	A_DB_IP			The IP address used to connect to remote primary database from this host. It should be set to:
###				- the database public IP, when remote database is reachable via internet only
###				- the database private IP, when remote database is reachable via Dynamic Routing GW (RECOMMENDED)
###				Note for RAC: If remote db is a RAC, set this value to one of the scan IPs (you MUST use Dynamic Routing Gateway).
###				Ideally scan address name should be used for remote RAC, but that dns name is not usually resolvable from local region.
###				Complete set of scan ips is automatically gathered later by the script.
###
###	A_PORT			The port of remote primary database's TNS Listener.
###
###	PDB_SERVICE_PRIMARY	The service name of the remote primary PDB. 
###				In case of RAC, if you use a CRS service to connect to the PDB, you can provide it instead default PDB service.
###
###	SYS_DB_PASSWORD		The password for the remote primary database SYS user.
###
###	DR_METHOD		The DR method that is going to be used for the DR setup and topology. Can be DBFS or RSYNC:
###				- DBFS:         When using DBFS method.
###						The domain config replication to secondary site is done via DBFS and Data Guard replica.
###				- RSYNC:        When using FSS with rsync method.
###						The domain config replication to the secondary site will be done via rsync. This script assumes that
###						you followed the steps described in the DR whitepaper to prepare the environment and the FSS is mounted in /fssmount.


# Check that this is running by oracle
if [ "$(whoami)" != "oracle" ]; then
        echo "Script must be run as user: oracle"
        exit 1
fi

#export VERBOSE=true


######################################################################################################################
# INPUT PARAMETERS SECTION
######################################################################################################################
###

if [[ $# -ne 0 ]]; then
        export DR_METHOD=$5
        if  [[ $DR_METHOD = "DBFS" ]]; then
                if [[ $# -eq 5 ]]; then
	        	export A_DB_IP=$1
		        export A_PORT=$2
		        export PDB_SERVICE_PRIMARY=$3
		        export SYS_USER_PASSWORD=$4
                else
                        echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $5. Expected 5, got $#"
                        echo "Usage for DR_METHOD=DBFS:"
                        echo "      $0  A_DB_IP  A_PORT  PDB_SERVICE_PRIMARY  SYS_DB_PASSWORD  DR_METHOD "
                        echo "Example: "
                        echo "      $0 '10.0.0.11' '1521' 'soapdb.sub19281336420.soacsdrvcn.oraclevcn.com' 'my_sysdba_password' 'DBFS' "
                        echo ""
                        exit 1
                fi

        elif [[ $DR_METHOD = "RSYNC" ]]; then
                if [[ $# -eq 5 ]]; then
                        export A_DB_IP=$1
                        export A_PORT=$2
                        export PDB_SERVICE_PRIMARY=$3
                        export SYS_USER_PASSWORD=$4
                else
                        echo ""
                        echo "ERROR: Incorrect number of parameters used for DR_METHOD $5. Expected 5, got $#"
                        echo "Usage for DR_METHOD=RSYNC:"
                        echo "    $0  "
                        echo "Example: $0  A_DB_IP  A_PORT  PDB_SERVICE_PRIMARY  SYS_DB_PASSWORD  DR_METHOD "
                        echo "    $0   '10.0.0.11' '1521' 'soapdb.sub19281336420.soacsdrvcn.oraclevcn.com' 'my_sysdba_password' 'RSYNC' "
                        echo ""
                        exit 1
                fi
        else
                echo ""
                echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $5"
		echo "Usage: "
		echo "	$0 A_DB_IP  A_PORT  PDB_SERVICE_PRIMARY  SYS_DB_PASSWORD  DR_METHOD"
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
	# Get the DB IP address
	echo
	echo "Please enter values for each script input when prompted below:"
	echo
	echo "(1) Enter the IP address used to connect to the primary database from this host."
	echo "    The IP address should be set to:"
	echo "        - the primary database's public IP, when the database is reachable via internet only"
	echo "        - the primary database's private IP, when the database is reachable via Dynamic Routing Gateway."
	echo "        Note: If a RAC database is used, set this value to any one of the RAC database's scan IPs."
	echo
	echo " Enter primary database IP address: "

	read -r A_DB_IP

	# Get the DB port
	echo
	echo "(2) Enter the primary database port number used to connect from this host."
	echo "    Note: this is usually configured as 1521"
	echo
	echo " Enter primary database connect port: "

	read -r A_PORT

	# Get the PDB service name
	echo
	echo "(3) The service name of the pdb used for primary database. "
	echo "    Note: This string has a format similar to pdb1.sub10213758021.soavcnfra.oraclevcn.com"
	echo
	echo " Enter primary PDB service name: "

	read -r PDB_SERVICE_PRIMARY

	# Get the DB SYS password
        while true; do
                echo
                echo "(4) The primary database SYS user's password"
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
	echo "(5) Enter the method that is going to be used for the DR setup"
	echo "    The DR Method should be set to:"
	echo "        - DBFS:  When using DBFS method. The domain config replication to secondary site is done via Data Guard replica."
	echo "        - RSYNC: When using FSS with rsync method. The domain config replication to the secondary site will be done via rsync."
	echo
	echo " Enter DR METHOD (DBFS or RSYNC): "

	read -r DR_METHOD
	
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
        if [ -z "${DOMAIN_HOME}" ];then
                echo "\$DOMAIN_HOME is empty. This variable is predefined in the oracle user's .bashrc. Example: export DOMAIN_HOME=/u01/data/domains/my_domain"
                exit 1
        else
                export WLS_DOMAIN_NAME=$(echo ${DOMAIN_HOME} |awk -F '/u01/data/domains/' '{print $2}')
        fi

        export date_label=$(date '+%d-%m-%Y-%H-%M-%S')
        export dt=$(date +%H_%M_%S-%d-%m-%y)

        export DATASOURCE_NAME=opss-datasource-jdbc.xml
        if [ -f "${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}" ]; then
                echo "The datasource ${DATASOURCE_NAME} exists"
        else
                echo "The datasource ${DATASOURCE_NAME} does not exist"
                echo "Provide an alternative datasource name"
                exit 1
        fi
    	export A_JDBC_URL=$A_DB_IP:$A_PORT/$PDB_SERVICE_PRIMARY
	
	if [[ ${VERBOSE} = "true" ]]; then	
		echo "COMMON VARIABLES for dbfs and rsync methods:"
		echo " DOMAIN_HOME............................." $DOMAIN_HOME
		echo " DATASOURCE_NAME........................." $DATASOURCE_NAME
		echo " PROVIDED A_JDBC_URL....................." $A_JDBC_URL
	fi
	
	#OTHER VARIABLES THAT DEPEND ON THE DR METHOD
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
	#PREDEFINED VARIABLES FOR RSYNC METHOD
	export FSS_MOUNT=/fssmount
	export COPY_FOLDER=${FSS_MOUNT}/domain_config_copy
	
	if [[ ${VERBOSE} = "true" ]]; then
		echo "SPECIFIC VARIABLES FOR RSYNC METHOD:"
		echo " FSS_MOUNT............................" ${FSS_MOUNT}
		echo " COPY_FOLDER.........................." ${COPY_FOLDER}
	fi

        # Note than when the method is RSYNC, we cannot use the db client to gather any value
	# Gather other variables (using wlst)
	check_if_RAC_nosqlplus
	gather_secondary_variables_from_DS
	get_CBD_values_nosqlplus
	
}

get_variables_in_secondary_DBFS(){
	# PREDEFINED VARIABLES FOR DBFS MERTHOD
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
	export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
	export PATH=$PATH:$ORACLE_HOME/bin
	export SYS_USERNAME=sys
	export CONNECT_TIMEOUT=10
	export RETRY_COUNT=10
	export RETRY_DELAY=10

        # NOTE than when the method is DBFS, we can use db client
	#Gather othe rvariables (using sqlplus)
	check_if_RAC
	gather_secondary_variables_from_DS
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
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@${A_JDBC_URL} "as sysdba"
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


gather_secondary_variables_from_DS() {
        echo ""
        echo "Getting variables from the datasource ..............."
    	# Secondary JDBC URL is obtained in the same way regardless RAC IS USED or NOT
	export LOCAL_JDBC_URL=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
	# If RAC is not used this will be null
    	export LOCAL_ONS_ADDRESS=$(grep ons-node-list ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '[<>]' '{print $3}')

	# The gathering of these variables is different depending if RAC is used or not
	if [ $RAC = "true" ]; then
		echo " RAC database is used"
		export PDB_NAME=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'SERVICE_NAME=' '{print $2}' | awk -F ')' '{print $1}' | awk -F '.' '{print $1}')
		export B_PRIV_HN=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'HOST=' '{print $2}' | awk -F ')' '{print $1}')
		export B_PORT=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'PORT=' '{print $2}' | awk -F ')' '{print $1}')
		export PDB_SERVICE_SECONDARY=$(grep url  ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME}  | awk -F 'SERVICE_NAME=' '{print $2}' | awk -F ')' '{print $1}')
	else
		echo " Single instance database is used"
		export PDB_NAME=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@' '{print $2}'| awk -F ':' '{print $2}' | awk -F '/' '{print $2}' | awk -F '.' '{print $1}')
		export B_PRIV_HN=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@//' '{print $2}' |awk -F '</url>' '{print $1}'| awk -F ':' '{print $1}')
		export B_PORT=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@' '{print $2}' | awk -F ':' '{print $2}' | awk -F '/' '{print $1}')
		export PDB_SERVICE_SECONDARY=$(grep url ${DOMAIN_HOME}/config/jdbc/${DATASOURCE_NAME} | awk -F '@//' '{print $2}' |awk -F '</url>' '{print $1}' | awk -F '/' '{print $2}')
	fi

	# Checks to make sure these variables are gathered
	if [[ ${PDB_NAME} = "" ]] ; then
		echo " ERROR: Cannot determine the PDB Name from the datasource"
		exit 1
	fi
	if [[ ${B_PRIV_HN} = "" ]] ; then
		echo " ERROR: Cannot determine the database hostname from the datasource"
		exit 1
	fi
	if [[ ${B_PORT} = "" ]] ; then
		echo " ERROR: Cannot determine the database port from the datasource"
		exit 1
	fi
	if [[ ${PDB_SERVICE_SECONDARY} = "" ]] ; then
		echo " ERROR: Cannot determine the secondary PDB service name from the datasource"
		exit 1
	fi


	if [[ ${VERBOSE} = "true" ]]; then
		echo " Secondary Connect String................" $LOCAL_JDBC_URL
		echo " PDB Name................................" $PDB_NAME
		echo " Secondary private Hostname.............." $B_PRIV_HN
		echo " Secondary TNS Listener Port............." $B_PORT
		echo " Secondary PDB Service..................." $PDB_SERVICE_PRIMARY
	fi
        echo ""
}

get_CDB_values() {
	echo ""
        echo "Getting CDB specific values from the primary DB (sqlplus)............"

	#get primary CDB unique name
	export A_DBNM=$(
	echo "set feed off
	set pages 0
	select DB_UNIQUE_NAME from V\$DATABASE;
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${A_DBNM} = "" ]] ; then
		echo " ERROR: Cannot determine the primary DB unique name"
		exit 1
	fi

	#get primary db domain name
	export A_DB_DOMAIN=$(
	echo "set feed off
	set pages 0
	select value from v\$parameter where name='db_domain';
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${A_DB_DOMAIN} = "" ]] ; then
		echo " ERROR: Cannot determine the primary DB domain"
		exit 1
        fi


	#get standby CDB unique name
	export B_DBNM=$(
	echo "set feed off
	set pages 0
	select DB_UNIQUE_NAME from V\$DATAGUARD_CONFIG where DEST_ROLE like '%STANDBY%';
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@${A_JDBC_URL} "as sysdba"
	)
	# Checks to make sure these variables are gathered
	if [[ ${B_DBNM} = "" ]] ; then
		echo " ERROR: Cannot determine the standby db unique name"
		exit 1
	fi



	#get secondary CDB alias string from primary to extract the service and domain name
	export b_remote_alias_string=$(
	echo "set feed off
	set pages 0
	set lines 10000
	SELECT DBMS_TNS.RESOLVE_TNSNAME ('"${B_DBNM}"') from dual;
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@${A_JDBC_URL} "as sysdba"
	)
	# Removing additional CID entry at the end of the string
	b_remote_alias_string=$(echo $b_remote_alias_string  | awk -F '\\(CID=' '{print $1}')
	# Adding required closing parenthesis
	b_remote_alias_string=${b_remote_alias_string}"))"
        export B_CDB_SERVICE_NAME=$(echo $b_remote_alias_string | awk -F 'SERVICE_NAME=' '{print $2}' | awk -F ')' '{print $1}')
        export B_DB_DOMAIN=$(echo $B_CDB_SERVICE_NAME | awk -F ${B_DBNM}. '{print $2}')

	# Checks to make sure these variables are gathered
	if [[ ${B_CDB_SERVICE_NAME} = "" ]] ; then
		echo " ERROR: Cannot determine the standby CDB service name"
		exit 1
	fi
	if [[ ${B_DB_DOMAIN} = "" ]] ; then
		echo " ERROR: Cannot determine the standby DB service name"
		exit 1
	fi

	
        if [[ ${VERBOSE} = "true" ]]; then
		echo " Primary DB UNIQUE NAME.................." $A_DBNM		
		echo " Primary DB DOMAIN ......................" $A_DB_DOMAIN
		echo " Secondary DB UNIQUE NAME................" $B_DBNM
		echo " Secondary tns alias from primary ......." $b_remote_alias_string
		echo " Secondary CDB service name ............." $B_CDB_SERVICE_NAME
		echo " Secondary DB DOMAIN ...................." $B_DB_DOMAIN
	fi
        echo ""

}

get_CBD_values_nosqlplus(){
        echo ""
        echo "Getting CDB specific values from the primary DB (wlst) ............."

        export jdbc_url="jdbc:oracle:thin:@"${A_JDBC_URL}
        export username="sys as sysdba"
        export password=${SYS_USER_PASSWORD}

        #get primary CDB unique name
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
		echo " ERROR: Cannot determine the primary DB unique name"
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
		echo " ERROR: Cannot determine the primary DB domain"
		exit 1
	fi

        #get secondary CDB unique name
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
		echo " ERROR: Cannot determine the standby DB unique name"
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
        export b_remote_alias_string=$(echo $result | awk -F \' '{print $2}')
        # Removing additional CID entry at the end of the string
        b_remote_alias_string=$(echo $b_remote_alias_string  | awk -F '\\(CID=' '{print $1}')
        # Adding required closing parenthesis
        b_remote_alias_string=${b_remote_alias_string}"))"
        export B_CDB_SERVICE_NAME=$(echo $b_remote_alias_string | awk -F 'SERVICE_NAME=' '{print $2}' | awk -F ')' '{print $1}')
        export B_DB_DOMAIN=$(echo $B_CDB_SERVICE_NAME | awk -F ${B_DBNM}. '{print $2}')
	# Checks to make sure these variables are gathered
	if [[ ${B_CDB_SERVICE_NAME} = "" ]] ; then
		echo " ERROR: Cannot determine the standby CDB service name"
		exit 1
	fi
	if [[ ${B_DB_DOMAIN} = "" ]] ; then
		echo " ERROR: Cannot determine the standby DB service name"
		exit 1
	fi

	if [[ ${VERBOSE} = "true" ]]; then
	        echo " Primary DB UNIQUE NAME................" $A_DBNM
		echo " Primary DB DOMAIN ...................." $A_DB_DOMAIN
		echo " Secondary DB UNIQUE NAME.............." $B_DBNM	
		echo " Secondary tns alias from primary......" $b_remote_alias_string
		echo " Secondary CDB service name ..........." $B_CDB_SERVICE_NAME
		echo " Secondary DB DOMAIN .................." $B_DB_DOMAIN
	fi
	echo ""

}


######################################################################################################################
############################## FUNCTIONS TO CHECK ####################################################################
######################################################################################################################
checks_in_secondary(){
        echo ""
        echo "************** CHECKS IN SECONDARY ********************************************"
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
        echo "Checking current database role........"
	check_secondary_db_role
	if  [[ ${db_role} = *"PHYSICAL STANDBY"* ]];then
		echo "     Database is in the expected mode. Continuing with the setup.."
	elif [[ ${db_role} = *"SNAPSHOT STANDBY"* ]];then
		echo "     Error: secondary database must be in physical standby mode."
                exit 1
        fi
	# The dbfs mount is checked later in prepare_secondary step,
	# once the db is converted to snapshot
}

check_secondary_db_role(){
	export jdbc_url="jdbc:oracle:thin:@"${B_PRIV_HN}:${B_PORT}/${B_DBNM}.${B_DB_DOMAIN}
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
	echo " Secondary database role is $db_role "
}


check_and_retry_mount() {
    echo "Checking DBFS mount point............"
    if mountpoint -q $DBFS_MOUNT; then
        echo " Mount at $DBFS_MOUNT is ready!"
        return 1
    else
        echo "DBFS Mount point not available. Will try to mount again..."
        ${DBFS_MOUNT_SCRIPT}
        sleep 10
        if mountpoint -q $DBFS_MOUNT; then
            echo " Mount at $DBFS_MOUNT is ready."
         else
            echo " Error: DBFS Mount point not available even after another try to mount. Check your DBFS set up."
            echo " If the DB does not allow read-only mode and it is a pshysical standby, this is expected."
            exit 1
        fi
    fi
}

######################################################################################################################
###################################### FUNCTIONS TO BACKUP sECONDARY #################################################
######################################################################################################################



create_domain_backup() {
	echo ""
	echo "************** BACKUP SECONDARY DOMAIN *****************************************"
	echo "Backing up domain to backup dir: ${DOMAIN_HOME}_backup_$dt"
        cp -R ${DOMAIN_HOME}/ ${DOMAIN_HOME}_backup_$dt
        echo "Backup created!"

}


######################################################################################################################
###################################### FUNCTIONS TO PREPARE SECONDARY #################################################
######################################################################################################################


prepare_secondary(){
        echo ""
        echo "************** PREPARE SECONDARY *** *******************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                prepare_secondary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                prepare_secondary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}

prepare_secondary_RSYNC(){
	#We have to create a file with local CDB url, for the config replica
	export CDB_SERVICE_FILE=/u01/data/domains/local_CDB_jdbcurl.nodelete
	echo "Creating $CDB_SERVICE_FILE with local CDB service content for future usage...."
        echo "${B_PRIV_HN}:${B_PORT}/${B_DBNM}.${B_DB_DOMAIN}" > $CDB_SERVICE_FILE
}

prepare_secondary_DBFS(){
	# In WLS DR we do not need to re-configure dbfs because it is already configured with dbfs_root script
	# We need to convert to snapshot, create aliases and mount dbfs
        convert_standby "SNAPSHOT STANDBY"
	get_primary_alias
	configure_tnsnames

        # We need to create a file with local CDB url, will be used by the config replica script
        export CDB_SERVICE_FILE=/u01/data/domains/local_CDB_jdbcurl.nodelete
        echo "Creating $CDB_SERVICE_FILE with local CDB service for future usage................"
	echo "${B_PRIV_HN}:${B_PORT}/${B_DBNM}.${B_DB_DOMAIN}" > $CDB_SERVICE_FILE

	# This is created for dgmgrl conversions, will be used by the config replica script 
	#(as in previous versions of dbfscopy.sh script) 
        echo "Creating ${DOMAIN_HOME}/dbfs/localdb.log with local CDB unique name for future usage...."
	echo $B_DBNM >  ${DOMAIN_HOME}/dbfs/localdb.log

	# Additional steps for SOAMP only
	if [[ ${PAAS} = "SOAMP" ]]; then
		get_dbfs_info_from_db
		recreate_dbfs_config
        fi
	
	# Now we can check and remount the dbfs
	check_and_retry_mount

}

convert_standby(){
        STANDBY_REQ_STATUS=$1
        echo "Converting standby to $STANDBY_REQ_STATUS"
        # We connect dgmgr to rremote DB since it is the primary
        export conversion_result=$(
        dgmgrl ${SYS_USERNAME}/\'${SYS_USER_PASSWORD}\'@\"${A_DB_IP}:${A_PORT}/${A_DBNM}.${A_DB_DOMAIN}\"  "convert database '${B_DBNM}' to ${STANDBY_REQ_STATUS}"

        )
        if [[ $conversion_result = *successful* ]]
        then
                echo "Standby DB Converted to $STANDBY_REQ_STATUS !"
        else
                echo "DB CONVERSION FAILED. CHECK DATAGUARD STATUS."
                exit 1
        fi
}


get_primary_alias(){
	export primary_alias_string=$(
        echo "set feed off
        set pages 0
        set lines 10000
        SELECT DBMS_TNS.RESOLVE_TNSNAME ('"${A_DBNM}"') from dual;
        exit
        "  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@${B_PRIV_HN}:${B_PORT}/${B_DBNM}.${B_DB_DOMAIN} "as sysdba"
        )
	if [[ ${VERBOSE} = "true" ]]; then
		echo " Primary tns alias string as gathered from secondary ......" $primary_alias_string
	fi
	# removing CID
	primary_alias_string=$(echo $primary_alias_string  | awk -F '\\(CID=' '{print $1}')
        # Adding required closing parenthesis
        primary_alias_string=${primary_alias_string}"))"

	if [[ ${VERBOSE} = "true" ]]; then
		echo " Primary tns alias string ................................." $primary_alias_string
	fi

}

configure_tnsnames () {
        echo "Configuring tnsnames.ora to add aliases to CDBs ............"
        mv ${TNS_ADMIN}/tnsnames.ora ${TNS_ADMIN}/tnsnames.ora_backup_$dt
        cat >> ${TNS_ADMIN}/tnsnames.ora <<EOF
${A_DBNM} =${primary_alias_string}

${B_DBNM} =
(DESCRIPTION =
  (SDU=65536)
  (RECV_BUF_SIZE=10485760)
  (SEND_BUF_SIZE=10485760)
  (ADDRESS = (PROTOCOL = TCP)(HOST = ${B_PRIV_HN})(PORT =${B_PORT}))
  (CONNECT_DATA =
   (SERVER = DEDICATED)
   (SERVICE_NAME = ${B_DBNM}.${B_DB_DOMAIN})
   )
)

${PDB_NAME} =
(DESCRIPTION =
 (CONNECT_TIMEOUT= ${CONNECT_TIMEOUT})(RETRY_COUNT=${RETRY_COUNT}) (RETRY_DELAY=${RETRY_DELAY})
 (ADDRESS = (PROTOCOL = TCP)(HOST = ${B_PRIV_HN})(PORT = ${B_PORT}))
 (CONNECT_DATA =
  (SERVER = DEDICATED)
  (SERVICE_NAME = ${PDB_SERVICE_SECONDARY})
 )
)
EOF
}


######### Following are SOAMP specific functions

get_dbfs_info_from_db(){
	# ONLY FOR SOA

	export PRIMARY_SCHEMA_PREFIX=$(
	echo  "set feed off
	set pages 0
	select DBFS_PREFIX from DBFS_INFO;
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@$A_DB_IP:$A_PORT/$PDB_SERVICE_PRIMARY "as sysdba"
	)

	export DBFS_SCHEMA_PASSWORD_ENCRYPTED=$(
	echo  "set feed off
	set pages 0
	select DBFS_PASSWORD from DBFS_INFO;
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@$A_DB_IP:$A_PORT/$PDB_SERVICE_PRIMARY "as sysdba"
	)
	
	export DBFS_SCHEMA_PASSWORD=$(
	echo  "set feed off
	set pages 0
	select UTL_RAW.CAST_TO_varchar2(DBMS_CRYPTO.decrypt('$DBFS_SCHEMA_PASSWORD_ENCRYPTED', 4353,  UTL_RAW.CAST_TO_RAW ('$SYS_USER_PASSWORD'))) from dual;
	exit
	"  | sqlplus -s $SYS_USERNAME/${SYS_USER_PASSWORD}@$A_DB_IP:$A_PORT/$PDB_SERVICE_PRIMARY "as sysdba"
        )

}

recreate_dbfs_config(){
	# ONLY FOR SOA
        echo "Recreating DBFS artifacts.................................."
	unset ORACLE_HOME
	echo "Unmounting current dbfs mounts..."
	fusermount -u $DBFS_MOUNT_IO
	fusermount -u $DBFS_MOUNT
	echo "Unmounted!"
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
############################### FUNCTIONS TO SYNC IN SECONDARY #########################################################
######################################################################################################################

sync_in_secondary(){
        echo ""
        echo "************** SYNC IN SECONDARY *******************************************"
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
        echo "Rsyncing from FSS  mount to domain dir..."
        rm  -rf ${DOMAIN_HOME}/servers/*
        hostnm=$(hostname)
        if [[ $hostnm == *"-0"* ]]; then
                # if this is Weblogic Administration server node, copy all except tmp
		# (not valid for SOACS), because admin is wls-1 in that case
                echo " This is the Weblogic Administration server node"
                sleep 10
                rsync -avz  --exclude 'tmp' ${COPY_FOLDER}/$WLS_DOMAIN_NAME/ ${DOMAIN_HOME}/
        else
                echo " This is not the Weblogic Administration server node"
                sleep 10
                # if this is not the Weblogic Administration server node, exclude copy servers folder also
                rsync -avz  --exclude 'tmp' --exclude '/servers/' ${COPY_FOLDER}/$WLS_DOMAIN_NAME/ ${DOMAIN_HOME}/
                fi
        echo $(date '+%d-%m-%Y-%H-%M-%S') > ${DOMAIN_HOME}/last_secondary_update.log
        echo "Rsync complete!"
     
}

sync_in_secondary_DBFS(){
	echo "Rsyncing from dbfs mount to domain dir..."
	rm  -rf ${DOMAIN_HOME}/servers/*
	hostnm=$(hostname)
	if [[ $hostnm == *"-0"* ]];then
		# if this is Weblogic Administration server node, copy all except tmp
                # (not valid for SOACS), because admin is wls-1 in that case
        	echo " This is the Weblogic Administration server node"
	        sleep 10
        	rsync -avz  --exclude 'tmp' $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME/ ${DOMAIN_HOME}/
	else
		echo " This is not the Weblogic Administration server node"
		sleep 10
		# if this is not the Weblogic Administration server node, exclude copy servers folder also
		rsync -avz  --exclude 'tmp' --exclude '/servers/' $DBFS_MOUNT_PATH/$WLS_DOMAIN_NAME/ ${DOMAIN_HOME}/
	fi
	echo $(date '+%d-%m-%Y-%H-%M-%S') > ${DOMAIN_HOME}/last_secondary_update.log
    	echo "Rsync complete!"
}


######################################################################################################################
############################### FUNCTIONS TO RETRIEVE AND REPLACE CONNECT INFOR ######################################
######################################################################################################################
retrieve_remote_jdbc_url(){
        echo ""
        echo "************** RETRIEVE REMOTE CONNECT JDBC URL *******************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                retrieve_remote_jdbc_url_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                retrieve_remote_jdbc_url_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}


retrieve_remote_jdbc_url_RSYNC(){
        export REMOTE_JDBC_URL=$(grep url ${COPY_FOLDER}/$WLS_DOMAIN_NAME/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
        echo "Remote Connect String................" $REMOTE_JDBC_URL

        # For RAC ons node list
        export REMOTE_ONS_ADDRESS=$(grep ons-node-list ${COPY_FOLDER}/${WLS_DOMAIN_NAME}/config/jdbc/${DATASOURCE_NAME} | awk -F '[<>]' '{print $3}')
}


retrieve_remote_jdbc_url_DBFS(){
	export REMOTE_JDBC_URL=$(grep url ${DBFS_MOUNT_PATH}/$WLS_DOMAIN_NAME/config/jdbc/${DATASOURCE_NAME} | awk -F ':@' '{print $2}' |awk -F '</url>' '{print $1}')
       	echo "Remote Connect String................" $REMOTE_JDBC_URL

        # For RAC ons node list
	export REMOTE_ONS_ADDRESS=$(grep ons-node-list ${DBFS_MOUNT_PATH}/${WLS_DOMAIN_NAME}/config/jdbc/${DATASOURCE_NAME} | awk -F '[<>]' '{print $3}')
}

replace_connect_info(){
	echo ""
        echo "************** Replacing instance specific DB connect information *****************************************"

	echo "Replacing jdbc url in config files..........................."
        echo "-------------------------------------------------------------"
	cd ${DOMAIN_HOME}/config/
	echo "String for primary...................." ${REMOTE_JDBC_URL}
	echo "String for secondary.................." ${LOCAL_JDBC_URL}
        find . -name '*.xml' | xargs sed -i 's|'${REMOTE_JDBC_URL}'|'${LOCAL_JDBC_URL}'|gI'
        echo "Replacement complete!"

        # TBD
        # To update other datasources where the string is not exactly the same than in opps (i.e: they use other service name)
        #echo "Replacing instance specific scan name in datasources with differen url (i.e: different service name)..."
        #echo "-------------------------------------------------------------------------------------------------------"
        #cd ${DOMAIN_HOME}/config/jdbc/
        #echo "Db address for primary...................." $REMOTE_CONNECT_ADDRESS
        #echo "Db address for secondary.................." $LOCAL_CONNECT_ADDRESS
        #find . -name '*.xml' | xargs sed -i 's|'${REMOTE_CONNECT_ADDRESS}'|'${LOCAL_CONNECT_ADDRESS}'|g'
        #echo "Replacement complete!"

        if [ "${REMOTE_ONS_ADDRESS}" != "" ];then
          echo "Replacing instance specific ONS node list in jdbc files......"
          echo "-------------------------------------------------------------"
          cd ${DOMAIN_HOME}/config/jdbc/
          echo "String for current primary...................." $REMOTE_ONS_ADDRESS
          echo "String for current secondary.................." $LOCAL_ONS_ADDRESS
          find . -name '*.xml' | xargs sed -i 's|'${REMOTE_ONS_ADDRESS}'|'${LOCAL_ONS_ADDRESS}'|g'
          echo "Replacement complete!"
        fi


}

######################################################################################################################
############################### FUNCTIONS POST SYNC AND REPLACE ############### ######################################
######################################################################################################################

post_steps_in_secondary(){
        echo ""
        echo "************** POST STEPS SECONDARY ************************************************"
        if  [[ ${DR_METHOD} = "RSYNC" ]]; then
                post_steps_in_secondary_RSYNC
        elif [[ ${DR_METHOD} = "DBFS" ]];then
                post_steps_in_secondary_DBFS
        else
                echo "Error. DR topology unknown"
                exit 1
        fi
        echo ""
}


post_steps_in_secondary_RSYNC(){
	# Nothing to do
        echo "nothing to do in RSYNC method"
}

post_steps_in_secondary_DBFS(){
        echo "nothing to do in DBFS method"

}



######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################



######################################################################################################################
# MAIN
######################################################################################################################
echo "*********************************************************************************************"
echo "********************************Preparing Secondary FMW for DR*******************************"
echo "*** Before running this script make sure of the following:                                ***"
echo "*** 1.- fmw_primary has been run in the primary WLS Administration server node            ***"
echo "*** 2.- Node manager and WLS servers are stopped in this node                             ***"
echo "*** 3.- The database is physical standby (not a snapshot standby)                         ***"
echo "*** 4.- You have provided the required primary db parameters (as input or interactively)  ***"
echo "*** 5.- You have followed the steps described in the  DR whitepaper to prepare            ***"
echo "***     the environment for the specific DR method you are using.                         ***"
echo "*********************************************************************************************"
echo "*********************************************************************************************"

get_DR_method
get_variables
checks_in_secondary
create_domain_backup
prepare_secondary
sync_in_secondary
retrieve_remote_jdbc_url
replace_connect_info
#post_steps_in_secondary

echo "************************************************************************************************"
echo "*******************************************Finished*********************************************"
echo "************************************************************************************************"

######################################################################################################################
# END OF MAIN
######################################################################################################################

