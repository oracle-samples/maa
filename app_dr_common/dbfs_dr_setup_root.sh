#!/bin/bash

## dbfs_dr_setup_root.sh version 2.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### Description: Script to configure DBFS in a middle tier node (typically for DR configuration)
### It installs Oracle Database Client, installs fuse, creates DBFS DB schemas, configures wallet and mounts DBFS file system
### NOTE: This script use yum commands to install fuse and the OS packages required by DB client. Make sure that yum is correctly 
###       configured in this host with the appropriate yum repository.
### NOTE: This script installs the OS packages required by DB Client that are not included in WLS for OCI stack images out-of-the-box.
###       If any additional OS package is missing, install it manually with yum. Check DB client package requirements in:
###       For DB Client 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/lacli/operating-system-requirements-for-x86-64-linux-platforms.html#GUID-3F647617-7FF5-4EE4-BBA8-9A5E3EEC888F
###       For DB Client 21c: https://docs.oracle.com/en/database/oracle/oracle-database/21/lacli/operating-system-requirements-for-x86-64-linux-platforms.html#GUID-3F647617-7FF5-4EE4-BBA8-9A5E3EEC888F

#### This script can run in interactive as well as non-interactive mode.  In the interactive
#### mode, the user simply runs the script using the script name and the script prompts for all
#### required inputs.  In the non-interactive mode, these inputs must be provided as command 
#### line arguments to the script (See below for usage).
####
#### The following variables are required by the script for execution:
#### (1) Address used to connect to the database from this host. It should be set to:
####       - the database hostname. This needs to be resolvable and reachable from this node. (Preferred)
####       - the database IP. This IP needs to be reachable from this node.
####        Note for RAC: 
####		If a RAC database is used, set this value to the RAC database's scan address name (need to be resolvable from this node).
####            If that name is not resolvable from the nodes mounting the DBFS file system you may provide one of the scan IPs instead.
####		The tnsnames.ora file may be updated later to reflect a list of the scan IPs also.
#### (2) The port of the database's TNS Listener
#### (3) The service name used to access the PDB
#### (4) The password for the database's SYS user
#### (5) The location of the db client installer. If skipping db client installation (using INSTALL_DBCLIENT=NO), no need to provide this parameter.

####
#### Interactive usage:
####         dbfs_dr_setup_root.sh       (NOTE: User will be prompted for all values)
####
#### Non-interactive usage:
####         dbfs_dr_setup_root.sh  DB_ADDRESS  DB_PORT  PDB_SERVICE  SYS_DB_PASSWORD INSTALL_FILE
####         dbfs_dr_setup_root.sh  'dbhost.mysubnet.myvcn.oraclevcn.com' '1521' 'soapdb.mysubnet.myvcn.oraclevcn.com' 'my_sysdba_password' '/tmp/V982064-01.zip'


#######################################################################
# CUSTOMIZABLE VARIABLES 
# For "WLS for OCI" DR (OCI to OCI), keep the default values, DO NOT modify them.
# For other scenarios (e.g. WLS Hybrid DR, on-premises hosts), customize to your env's values.
#######################################################################
#  Set to NO to skip db client installation if it is already installed. Default is YES.
export INSTALL_DBCLIENT=YES

#  The oracle software owner and group. Default are oracle.
export ORACLE_OS_USER=oracle
export ORACLE_OS_GROUP=oracle

#  The db client home path. Default value is /u01/app/oracle/client
export DB_CLIENT_HOME=/u01/app/oracle/client
#  The Oracle base, normally the db client home's parent folder. Default value is /u01/app/oracle 
export ORACLE_BASE=/u01/app/oracle
#  The path to the db client inventory. Default value is /u01/app/client_oraInventory
export DB_CLIENT_INVENTORY=/u01/app/client_oraInventory

#  The folder where the DBFS artifacts (wallet, tnsnames.ora, mount script) will be placed. Example /home/oracle/dbfs_config. Leave empty in "WLS for OCI" envs.
export DBFS_CONFIG_DIR=

#  The database sys username. Default is sys.
export SYS_USERNAME=sys
#  The database username that will be created for the DBFS schema. Default is dbfsuser.
export DBFS_USER=dbfsuser
#  The tablespace name that will be created in the database to store the DBFS schema. Default is tbsdbfs.
export DBFS_TS=tbsdbfs
#  The DBFS folder that will be created in the DBFS schema. Default is dbfsdir.
export DBFS_DBDIR=dbfsdir
#  The mount point where the DBFS filesystem will be mounted in this host. Default value is /u02/data/dbfs_root
export DBFS_MOUNT_PATH=/u02/data/dbfs_root

#######################################################################


########################################################################
#Variables with fixed values. Do not modify.
########################################################################
export ORACLE_HOME=$DB_CLIENT_HOME
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
export PATH=$PATH:$ORACLE_HOME/bin
export MKSTORE=$ORACLE_HOME/bin/mkstore
export dt=$(date +%Y-%m-%d-%H_%M_%S)
export TMPDIR=/tmp
export rspfile=${TMPDIR}/dbclient_response.rsp
export LOGFILE=/tmp/dbfssetup$dt.log
export CONNECT_TIMEOUT=10
export RETRY_COUNT=10
export RETRY_DELAY=10
#For "WLS for OCI" DR, the dbfs config folder is hardcoded to DOMAIN_HOME/dbfs
if [ -z "$DBFS_CONFIG_DIR" ]; then
	export DOMAIN_HOME=$(sudo -Hiu ${ORACLE_OS_USER} env | grep DOMAIN_HOME | awk -F '=' '{print $2}')
	if [ -z "$DOMAIN_HOME" ]; then
		echo "Error: the DOMAIN_HOME variable is not defined in oracle user's env"
		echo "       If you are running this in a WLS for OCI host, verify that it is defined in the oracle user's env"
		echo "       If you are running this in other scenario, configure the DBFS_CONFIG_DIR variable in this script"
		exit 1
	fi
	export DBFS_CONFIG_DIR=${DOMAIN_HOME}/dbfs
fi
export DBFSMOUNTSCR=${DBFS_CONFIG_DIR}/dbfsMount.sh
########################################################################


#Check that this is running by oracle root
if [ "$(whoami)" != "root" ]; then
        echo "Script must be run as user: root"
        exit 1
fi


create_backup(){
	if test -f $1; then
		echo "$1 exists, creating a backup..."  >> $LOGFILE
		su - oracle -c "mv $1 $1_backup_$dt"
	fi
}

check_user(){
	gexists=$(grep -c "^${ORACLE_OS_GROUP}:" /etc/group)
	if [ $gexists -eq 0 ]; then
		echo "Error: Group $ORACLE_OS_GROUP does not exist"
		exit 1
	fi
	uexists=$(grep -c "^${ORACLE_OS_USER}:" /etc/passwd)
	if [ $uexists -eq 0 ]; then
		echo "Error: User $ORACLE_OS_USER does not exist"
		exit 1
	fi
}

create_dirs(){
	if [[ ! -d "${ORACLE_BASE}" ]]; then
		mkdir -p $ORACLE_BASE
        	chown ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} $ORACLE_BASE
	fi
	if [[ ! -d "${DB_CLIENT_INVENTORY}" ]]; then
		mkdir -p $DB_CLIENT_INVENTORY
		chown ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} $DB_CLIENT_INVENTORY
	fi

	if [[ ! -d "${DBFS_CONFIG_DIR}" ]]; then
		mkdir -p ${DBFS_CONFIG_DIR}
		chown ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} ${DBFS_CONFIG_DIR}
	fi
	
	if [[ ! -d "${DBFS_MOUNT_PATH}" ]]; then
		mkdir -p ${DBFS_MOUNT_PATH}
		chown ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} ${DBFS_MOUNT_PATH}
	fi
}

install_required_packages(){
        echo "Installing packages required by the DB Client Installer..." >> $LOGFILE
	yum install libstdc++-devel -y >> $LOGFILE
	yum install ksh -y >> $LOGFILE
	yum install glibc-devel -y >> $LOGFILE
	yum install libaio-devel -y >> $LOGFILE
	yum install psmisc -y >> $LOGFILE
	yum install compat-libcap1 -y >> $LOGFILE
	echo "You can ignore the Error: \"Unable to find a match: compat-libcap1\" in OEL 8 operating systems since this package no longer exists in this OEL version." >> $LOGFILE
}

prepare_response_file(){
rm -f ${rspfile}
cat >> ${rspfile} <<EOF
#-------------------------------------------------------------------------------
# Do not change the following system generated value.
#-------------------------------------------------------------------------------
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v18.0.0

#-------------------------------------------------------------------------------
# Unix group to be set for the inventory directory.
#-------------------------------------------------------------------------------
UNIX_GROUP_NAME=${ORACLE_OS_GROUP}
#-------------------------------------------------------------------------------
# Inventory location.
#-------------------------------------------------------------------------------
INVENTORY_LOCATION=${DB_CLIENT_INVENTORY}
#-------------------------------------------------------------------------------
# Complete path of the Oracle Base.
#-------------------------------------------------------------------------------
ORACLE_BASE=${ORACLE_BASE}
ORACLE_HOME=${ORACLE_HOME}
oracle.install.client.installType=Administrator
EOF
chown ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} $rspfile
chmod o+r $rspfile
}

install_db_client() {
	echo "Unpacking db client installables..." >> $LOGFILE
	if [ ! -f $INSTALL_FILE ] || [ -z "$INSTALL_FILE" ]; then
		echo "Error: Install file $INSTALL_FILE does not exist or not correctly provided"
		exit 1
	fi
	su - ${ORACLE_OS_USER} -c "cd $ORACLE_BASE; unzip -o $INSTALL_FILE  -d $TMPDIR" >> $LOGFILE
	su - ${ORACLE_OS_USER} -c "$TMPDIR/client/runInstaller -silent -responseFile $rspfile" >> $LOGFILE
	echo ""
	PIDW2=$(ps -ef | grep "oracle.install.ivw.client.driver.ClientInstaller"  | grep -v grep | head -n 1| awk '{print $2}')
	tail --pid=$PIDW2 -f /dev/null
	echo "Db Client Install process finished" >> $LOGFILE
	SQLPLUSFILE=$ORACLE_HOME/bin/sqlplus
	if test -f "$SQLPLUSFILE"; then
		echo "$SQLPLUSFILE found. DB client installation complete." >> $LOGFILE
	else
		echo "$SQLPLUSFILE not found. DB Client installation failed. Review logs" >> $LOGFILE
		exit 1
	fi
}

test_db_conn() {
	export db_read_type=$(
		echo "set feed off
		set pages 0
		select open_mode from v\$database;
		exit
		"  | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@$DB_ADDRESS:$DB_PORT/$PDB_SERVICE "as sysdba"
		)
	if  [[ $db_read_type = *READ* ]]; then
		echo "Sys password is valid and DB is in correct status ($db_read_type). Proceeding..." >> $LOGFILE
	else
		echo "Invalid password or incorrect DB status";
		exit 1
	fi
}

install_fuse() {
	echo "Installing fuse packages" >> $LOGFILE
	yum install fuse-devel -y >> $LOGFILE
	yum install fuse -y >> $LOGFILE
	fgexists=$(grep -c "^fuse:" /etc/group)
        if [ $fgexists -eq 0 ]; then
                echo "Group fuse does not exists, creating..."  >> $LOGFILE
                groupadd fuse
        fi
	usermod -aG fuse ${ORACLE_OS_USER}
	echo "user_allow_other" >> /etc/fuse.conf
}

prepare_db(){
	echo "set feed off
	set pages 0
	create tablespace $DBFS_TS datafile size 1G autoextend on next 100m;
	create user $DBFS_USER identified by $SYS_USER_PASSWORD default tablespace $DBFS_TS quota unlimited on $DBFS_TS;
	grant connect, create table, create procedure, dbfs_role to $DBFS_USER; 
	exit
	" | sqlplus -s $SYS_USERNAME/$SYS_USER_PASSWORD@$DB_ADDRESS:$DB_PORT/$PDB_SERVICE "as sysdba" >> $LOGFILE

	echo "set feed off
	set pages 0
	@$ORACLE_HOME/rdbms/admin/dbfs_create_filesystem.sql $DBFS_TS $DBFS_DBDIR; 
	exit
	" | sqlplus -s $DBFS_USER/$SYS_USER_PASSWORD@$DB_ADDRESS:$DB_PORT/$PDB_SERVICE >> $LOGFILE
}

recreate_dbfswallet(){
	# Creating with root and then changing ownership to oracle (to avoid known issues due to oracle's user env's variables)
	fusermount -u $DBFS_MOUNT_PATH >> $LOGFILE
 	if [ -d "${DBFS_CONFIG_DIR}/wallet" ]; then
                mv ${DBFS_CONFIG_DIR}/wallet/ ${DBFS_CONFIG_DIR}/wallet_backup_$dt
        fi
        printf ${SYS_USER_PASSWORD}'\n'${SYS_USER_PASSWORD}'\n' | $MKSTORE -wrl ${DBFS_CONFIG_DIR}/wallet/ -create >> $LOGFILE
        export add_cred_command="-createCredential ${TNSID} ${DBFS_USER} ${SYS_USER_PASSWORD}"
        printf ${SYS_USER_PASSWORD}'\n' | $MKSTORE -wrl ${DBFS_CONFIG_DIR}/wallet/ ${add_cred_command} >> $LOGFILE
	chown -R ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} ${DBFS_CONFIG_DIR}/wallet
	echo "Wallet created in ${DBFS_CONFIG_DIR}/wallet"
}

configure_sqlclient(){
create_backup "${DBFS_CONFIG_DIR}/tnsnames.ora"
su - ${ORACLE_OS_USER} -c "cat >> ${DBFS_CONFIG_DIR}/tnsnames.ora <<EOF
${TNSID} =
  (DESCRIPTION =
    (CONNECT_TIMEOUT= ${CONNECT_TIMEOUT})(RETRY_COUNT=${RETRY_COUNT}) (RETRY_DELAY=${RETRY_DELAY})
	(ADDRESS = (PROTOCOL = TCP)(HOST = ${DB_ADDRESS})(PORT = ${DB_PORT}))
	(CONNECT_DATA =
	  (SERVER = DEDICATED)
	  (SERVICE_NAME = ${PDB_SERVICE})
   )
  )
EOF
"
create_backup  "${DBFS_CONFIG_DIR}/sqlnet.ora"
su - ${ORACLE_OS_USER} -c "cat >> ${DBFS_CONFIG_DIR}/sqlnet.ora <<EOF
WALLET_LOCATION =
  (SOURCE =
	(METHOD = FILE)
	(METHOD_DATA =
	  (DIRECTORY = ${DBFS_CONFIG_DIR}/wallet)
	)
  )

SQLNET.WALLET_OVERRIDE = TRUE

EOF
"
}

create_mount_dbfs_script(){
create_backup $DBFSMOUNTSCR
cat >> $DBFSMOUNTSCR <<EOF
#!/bin/sh
export ORACLE_HOME=$ORACLE_HOME
export TNS_ADMIN=$DBFS_CONFIG_DIR
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
export PATH=\$PATH:\$ORACLE_HOME/bin
export MOUNT_PATH=$DBFS_MOUNT_PATH

mkdir -p \$MOUNT_PATH

if mountpoint -q \$MOUNT_PATH ; then
    echo "DBFS is already mounted"
    exit
fi
cd ${DBFS_CONFIG_DIR}/
fusermount -u \$MOUNT_PATH >>dbfs.log
\$ORACLE_HOME/bin/dbfs_client -o ${DBFS_CONFIG_DIR}/wallet/ @$TNSID -o direct_io -o allow_other \$MOUNT_PATH &>>dbfs.log &

EOF

chown ${ORACLE_OS_USER}:${ORACLE_OS_GROUP} $DBFSMOUNTSCR
chmod u+x $DBFSMOUNTSCR
echo "Script to mount dbfs created at $DBFSMOUNTSCR"
}

mount_and_test(){
	su - ${ORACLE_OS_USER} -c "$DBFSMOUNTSCR"
	sleep 10
	mountready=$(mount | grep $DBFS_MOUNT_PATH )
	if [ -z "$mountready" ]; then
		echo "ERROR: dbfs mount failed at ${DBFS_MOUNT_PATH}. Check logs"
		exit 1
	else
		echo "SUCESS: dbfs mount ready at ${DBFS_MOUNT_PATH} "
	fi
}

add_to_cron(){
	crontcount=$(grep -c "$DBFSMOUNTSCR" /etc/crontab)
	if [ $crontcount -eq 0 ]; then
		echo "#Added to mount dbfs on boot" >> /etc/crontab
		echo "@reboot ${ORACLE_OS_USER} $DBFSMOUNTSCR" >> /etc/crontab
	fi
}

if [[ $# -ne 0 ]]; then
    if [[ $INSTALL_DBCLIENT == "YES" ]]; then
	    if [[ $# -ne 5 ]]; then
        	echo
        	echo "ERROR: Incorrect number of input variables passed to $0. Expected 5, got $#"
        	echo "Usage:    $0  DB_ADDRESS  DB_PORT  PDB_SERVICE  SYS_DB_PASSWORD INSTALL_FILE"
        	echo "Example:  $0  'dbhost-scan.mysubnet.myvcn.oraclevcn.com' '1521' 'soapdb.mysubnet.myvcn.oraclevcn.com' 'sysdba_password' '/tmp/V982064-01.zip' "
        	exit 1
	    else
	        export DB_ADDRESS=$1
	        export DB_PORT=$2
	        export PDB_SERVICE=$3
	        export SYS_USER_PASSWORD=$4
		export INSTALL_FILE=$5
	    fi
    else
            if [[ $# -ne 4 ]]; then
                echo
                echo "ERROR: Incorrect number of input variables passed to $0. When using INSTALL_DBLIENT=NO, expected 4, got $#"
                echo "Usage:    $0  DB_ADDRESS  DB_PORT  PDB_SERVICE  SYS_DB_PASSWORD "
                echo "Example:  $0  'dbhost-scan.mysubnet.myvcn.oraclevcn.com' '1521' 'soapdb.mysubnet.myvcn.oraclevcn.com' 'sysdba_password'"
                exit 1
            else
                export DB_ADDRESS=$1
                export DB_PORT=$2
                export PDB_SERVICE=$3
                export SYS_USER_PASSWORD=$4
                export INSTALL_FILE=
            fi
    fi
else
    # Get the DB address
    echo 
    echo "Please enter values for each script input when prompted below:"
    echo
    echo "(1) Enter the address used to connect to the database from this host."
    echo "    The address should be set to:"
    echo "        - the database hostname. This needs to be resolvable and reachable from this node. (Preferred)"
    echo "        - the database host IP. This IP needs to be reachable from this node."
    echo "        Note for RAC:"
    echo "            If a RAC database is used, set this value to the RAC database's scan address (need to be resolvable from this node)."
    echo "            If that name is not resolvable from the nodes mounting the DBFS file system you may provide one of the scan IPs instead."
    echo "            The tnsnames.ora file may be updated later to reflect a list of the scan IPs also."


 echo 
    echo " Enter database address: "

    read -r DB_ADDRESS

    # Get the DB port
    echo
    echo "(2) Enter the database port number used to connect from this host."
    echo "    Note: this is usually configured as 1521"
    echo 
    echo " Enter database connect port: "

    read -r DB_PORT

    # Get the PDB service name
    echo
    echo "(3) The service name used access the database. "
    echo "    Note: This string has a format similar to pdbservice.mysubnet.soavcnfra.oraclevcn.com"
    echo 
    echo " Enter DATABASE service name: "

    read -r PDB_SERVICE

    # Get the DB SYS password
    while true; do
        echo
        echo "(4) The database SYS user's password"
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

    # Get the DB client software installer location
    echo
    echo "(5) The full path to the db client installer location. "
    echo "    Note: This string has a format similar to /tmp/V982064-01.zip"
    echo "    Note: If you are using INSTALL_DBCLIENT=NO to skip the db client installation, then no need to provide this value."
    echo
    echo " Enter DB client software location: "
    read -r INSTALL_FILE


fi
echo "**********************************Installing DB Client and creating DBFS mounts*******************************************"

echo "Script will use the following parameters:"
echo " DB_ADDRESS            = ${DB_ADDRESS}"
echo " DB_PORT               = ${DB_PORT}"
echo " PDB_SERVICE           = ${PDB_SERVICE}"
export TNSID=$(echo $PDB_SERVICE  | awk -F '.' '{print $1}')
echo " TNS ALIAS             = ${TNSID}"
echo " SYS_USER_PASSWORD     = <Not displayed>"
echo " INSTALL_FILE          = ${INSTALL_FILE}"

check_user
create_dirs
if  [[ $INSTALL_DBCLIENT = "YES" ]]; then
	echo "**************************************************************************************************************************"
	echo "This may take some time...Please wait. A log for this set up is available at $LOGFILE"
	install_required_packages
	prepare_response_file
	install_db_client
fi
test_db_conn
install_fuse
prepare_db
recreate_dbfswallet
configure_sqlclient
create_mount_dbfs_script
mount_and_test
add_to_cron
echo "*************************************************DBFS set up complete *****************************************************"
echo "Check $LOGFILE for details"
echo "Script execution finished." >> $LOGFILE

