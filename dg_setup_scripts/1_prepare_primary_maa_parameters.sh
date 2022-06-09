#!/bin/bash

## dg_setup_scripts version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


# This script needs to be run by oracle user,  before configuring Data Guard.
# The script will connect to local database (primary) and:
# - will set the MAA recommended parameters for DG
# - will create the standby log files

# Parameter values that will be set:
export DB_FLASHBACK_RETENTION_TARGET=1440
export DB_BLOCK_CHECKSUM=FULL
export DB_BLOCK_CHECKING=FULL
export DB_LOST_WRITE_PROTECT=TYPICAL
export LOG_BUFFER=256M
export STANDBY_FILE_MANAGEMENT=AUTO

retrieve_current_log_values(){
	echo ""
	echo "Getting current log parameters........."

	export ONLINE_LOG_DEST1=$(
                echo "set feed off
                set pages 0
                select value from v\$parameter where name='db_create_online_log_dest_1';
		exit
                "  | sqlplus -s / as sysdba
		)
	echo " Parameter db_create_online_log_dest_1 ..... $ONLINE_LOG_DEST1"

	export REDOLOG_SIZE=$(
                echo "set feed off
                set pages 0
		select max(bytes) from  v\$log;
                exit
                "  | sqlplus -s / as sysdba
                )
	echo " Online redo log size (bytes) is ........... $REDOLOG_SIZE"

	export THREADS=$(
                echo "set feed off
                set pages 0
		select max(thread#) from v\$log;
		exit
                "  | sqlplus -s / as sysdba
		)
	echo " Online thread number is.................... $THREADS"

	export ONLINE_LOG_GROUPS=$(
                echo "set feed off
                set pages 0
                select max(group#) from v\$log;
                exit
                "  | sqlplus -s / as sysdba
                )
	echo " Online log groups number is ............... $ONLINE_LOG_GROUPS"
}

add_standby_logs(){
	# Standby logs will be created with same size than online logs (REDOLOG_SIZE)
	# Standby logs will be created in ONLINE_LOG_DEST1
	# Standby logs will have 1 group more than the online logs, same threads
	echo ""
	echo "Creating the required standby logs in primary DB......."
	declare -i online_group_number=$ONLINE_LOG_GROUPS
	declare -i online_group_per_thread=$(( online_group_number/THREADS ))
	declare -i stby_group_per_thread=$(( online_group_per_thread + 1 ))
	declare -i starting_stby_group_number=$(( ONLINE_LOG_GROUPS + 1 ))
	echo "  Existing online groups number: $online_group_number"
	echo "  Existing Online groups per thread: $online_group_per_thread "
	echo "  Standby groups per thread that will be created: $stby_group_per_thread"
	echo "  Starting number for standby group: $starting_stby_group_number"
	
        declare -i i=0
	declare -i g=$starting_stby_group_number
	while (($i < $THREADS ));do
		declare -i n=0
		i+=1
		while (($n < $stby_group_per_thread ));do
			n+=1
			echo "alter database add standby logfile thread $i group $g '$ONLINE_LOG_DEST1' size $REDOLOG_SIZE;"
			echo "alter database add standby logfile thread $i group $g '$ONLINE_LOG_DEST1' size $REDOLOG_SIZE;" | sqlplus -s / as sysdba
			g+=1
		done
        done
}

set_primary_maa(){
	echo ""
	echo "Setting recommended MAA parameters in DB:"
	echo "  Will set force logging"
	echo "  Will flashback on"
	echo "  DB_FLASHBACK_RETENTION_TARGET=${DB_FLASHBACK_RETENTION_TARGET}"
	echo "  remote_login_passwordfile='exclusive'"
	echo "  DB_BLOCK_CHECKSUM=${DB_BLOCK_CHECKSUM}"
	echo "  DB_BLOCK_CHECKING=${DB_BLOCK_CHECKING}"
	echo "  B_LOST_WRITE_PROTECT=${DB_LOST_WRITE_PROTECT}"
	echo "  LOG_BUFFER=${LOG_BUFFER}"
	echo "  STANDBY_FILE_MANAGEMENT=${STANDBY_FILE_MANAGEMENT}"
	$ORACLE_HOME/bin/sqlplus -s / as sysdba <<EOF
alter database force logging;
alter database flashback on;
alter system set DB_FLASHBACK_RETENTION_TARGET=${DB_FLASHBACK_RETENTION_TARGET} scope=both sid='*';
alter system set remote_login_passwordfile='exclusive' scope=spfile sid='*';
alter system set DB_BLOCK_CHECKSUM=${DB_BLOCK_CHECKSUM};
alter system set DB_BLOCK_CHECKING=${DB_BLOCK_CHECKING};
alter system set DB_LOST_WRITE_PROTECT=${DB_LOST_WRITE_PROTECT};
alter system set LOG_BUFFER=${LOG_BUFFER} scope=spfile sid='*';
alter system set STANDBY_FILE_MANAGEMENT=${STANDBY_FILE_MANAGEMENT} scope=both sid='*';
exit;
EOF
        echo "Primary settings applied!"
}


retrieve_current_log_values
add_standby_logs
set_primary_maa
