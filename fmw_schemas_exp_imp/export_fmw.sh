#!/bin/bash

## export_fmw.sh script version 1.0.
##
## Copyright (c) 2025 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates a packed extraction of the required tablespaces, schemas and roles used by Oracle FMW
### It uses Oracle Data Pump Export and DDL extraction from a PDB hosting a FMW system (typically JRF or SOA domain)
### to create a tar that can be transferred to another database system to "migrate" the original FMW domain.
### - It has to be executed in any of the FMW DB nodes.
### - It can move a FMW system to a different PDB or a totally different database (ideally in a PDB hosted by a  multitenant database).
### - It identifies the schemas based on the prefix provided in the Repository Creation Utility (RCU).
### - The precise list of schemas exported is configured in the script's variable "schema_list"- The default value provided
### for this variable is the on required to export a standard EDG FMW SOA on prem system.
### - It requires a tns alias mapping to a service (attached to a single instance in RAC configuration) to conect to the precise PDB.
### 	Create an instance-specific service and an alias for it in tnsnames.ora. Pending to be automated. For example:
### 	[oracle@fmwdbnode1 ~]$ srvctl add service -db $ORACLE_UNQNAME -service export_soaedg.example.com -preferred  SOADB231 -pdb SOADB23_pdb1
### 	[oracle@fmwdbnode1 ~]$ srvctl start service -s  export_soaedg.example.com -db $ORACLE_UNQNAME
### 	[oracle@fmwdbnode1 ~]$ lsnrctl status | grep export_soaedg.example.com
### 	Service "export_soaedg.example.com" has 1 instance(s).
### 	[oracle@fmwdbnode1 ~]$ cat /u01/app/oracle/product/23.0.0.0/dbhome_1/network/admin/tnsnames.ora | grep export
### 	EXPORT_SOADB23_PDB1=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=drdbrac12a-scan.dbsubnet.vcnlon80.oraclevcn.com)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=export_soaedg.example.com)(FAILOVER_MODE=(TYPE=select)(METHOD=basic))))
###
###
### Usage:
###
###      	./export_fmw.sh [TNS_ALIAS] [EXPORT_DIRECTORY]
### Where:
###		TNS_ALIAS:
###			Alias in tnsnames.ora that identifies the connect string to be used for the export
###		EXPORT_DIRECTORY:
###			Directory where datapum exports and sql scripts will be created

if [[ $# -eq 2 ]];
then
	export dt=`date +%y-%m-%d-%H-%M-%S`
	export tns_alias=$1
	export dumpdir=$2/FMW_EXPORTS_${dt}/
else
	echo ""
    	echo "ERROR: Incorrect number of parameters used: Expected 2, got $#"
    	echo ""
    	echo "Usage:"
    	echo "    $0 [TNS_ALIAS] [EXPORT_DIRECTORY]"
    	echo ""
    	echo "Example:  "
    	echo "    $0 EXPORT_SOADB23_PDB1 /u01/dbdataexports "
    	exit 1
fi

export beautify="
set long 65536; 
set linesize 1000;
set long 65536;
set trimspool on;
set null null;
set pagesize 0;
set newpage none;
set headsep off;
set feedback off;
set ver off;
set pause off;
set flush off;
column aaa format a1000;
set echo off;
set SERVEROUTPUT OFF;
set term off;
set head off;
set termout off;
set longchunksize 100000;
exec DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', FALSE);
exec DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
"

######################################################################################################################
# FUNCTIONS SECTION
######################################################################################################################

obtain_rcu_schema_list () {
outdir=$1
prefix=$2
sys_pass=$3
tns_alias=$4
log_dir=$5
sqlplus -s sys/""${sys_pass}""@${tns_alias} as sysdba > $logdir/rcu_schema_list_query.log << EOF
set feedback off;
column aaa format a1000;
set echo off;
set head off;
set termout off;
spool ON
spool ${outdir}/rcu_schema_list.cfg
select OWNER from SYSTEM.SCHEMA_VERSION_REGISTRY where OWNER like '${prefix}\_%' escape '\';
spool off
EOF
export rcu_schema_list=$(cat  ${outdir}/rcu_schema_list.cfg)
if [[ -z "$rcu_schema_list" ]];then
    echo "No schemas found with prefix $prefix. Make sure you provide an existing RCU prefix in the DB and retry."
    rm -rf ${outdir}/rcu_schema_list.cfg
    exit
else
    echo "Found the following RCU schemas: "
    echo $rcu_schema_list
fi

}

export_system_registry () {
#Using param file to avoid parsing errors with query
dumpdirname=$1
scn=$2
prefix=$3
sys_pass=$4
tns_alias=$5
logdir=$6
cfgdir=$7
echo "Exporting SCHEMA_VERSION_REGISTRY information for prefix $prefix."

waiting &
waitpid=$!

cat << EOF > $cfgdir/sysparam.cfg
SCHEMAS=system
INCLUDE=VIEW:"IN('SCHEMA_VERSION_REGISTRY')"
TABLE:"IN('SCHEMA_VERSION_REGISTRY$')"
directory="$dumpdirname"
dumpfile=SYSTEM_SCHEMA_VERSION_REGISTRY.dmp
logfile=SYSTEM_SCHEMA_VERSION_REGISTRY.dmplog
CLUSTER=N
encryption_password="$sys_pass"
flashback_scn=$scn
QUERY=SYSTEM.SCHEMA_VERSION_REGISTRY$:"where OWNER like '${prefix}|_%' escape'|'"
EOF
expdp \"sys/"${sys_pass}"@${tns_alias} as sysdba\" parfile=$cfgdir/sysparam.cfg > ${logdir}/system_schema_version_registry_export.log 2>&1
kill $waitpid 
wait $waitpid > /dev/null 2>&1
sed -i "s/$sys_pass/****/g" ${cfgdir}/sysparam.cfg
echo "SCHEMA_VERSION_REGISTRY export complete."
}


echo
echo "*********************************************************************************"
echo "*********************************************************************************"
echo "****************  Welcome to the WLS/FMW Oracle Data Pump utility! **************"
echo "*********************************************************************************"
echo "***********************STARTING EXPORT UTILITY***********************************"
echo "*********************************************************************************"
echo

export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $exec_path/common_export_import_fmw.sh
check_connection SYS $tns_alias

#PREPARE DIRS AND GATHER SCN.
export logdir=$dumpdir/export/logs
export cfgdir=$dumpdir/export/cfg
export rolesdir=$dumpdir/export/roles
export tablespacesdir=$dumpdir/export/tablespaces
export schemasdir=$dumpdir/export/schemas
mkdir -p $logdir
mkdir -p $cfgdir
mkdir -p $rolesdir
mkdir -p $tablespacesdir
mkdir -p $schemasdir
export dumpdirname=DUMP_INFRA

sqlplus -s sys/""${sys_pass}""@${tns_alias} as sysdba > $logdir/dump_dir_query.log << EOF
DROP DIRECTORY ${dumpdirname};
CREATE DIRECTORY ${dumpdirname} AS '$dumpdir';
GRANT READ,WRITE ON DIRECTORY ${dumpdirname} TO SYS;
set line 500;
column directory_name format a30;
column directory_path format a60;
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name='${dumpdirname}';
set feedback off;
column aaa format a1000;
set echo off;
set head off;
set termout off;
spool ON
spool ${cfgdir}/scn.cfg
SELECT trim(dbms_flashback.get_system_change_number) FROM DUAL;
spool off
exit
EOF
export scn=$(cat  ${cfgdir}/scn.cfg |tr -d '[:space:]')


#CONSTRUCT SCHEMA LIST
while true; do
	echo
	read -p "Are you exporting the database schemas for a FMW/JRF WebLogic Domain?: " yn1
  	case $yn1 in
		[Yy]* ) 
			read -p "Provide the FMW RCU prefix for the schemas:" prefix
			echo "$prefix" > $cfgdir/prefix.cfg
			obtain_rcu_schema_list $cfgdir $prefix $sys_pass $tns_alias $logdir
			echo $rcu_schema_list > $cfgdir/complete_schema_list.cfg
			export_system_registry $dumpdirname $scn $prefix $sys_pass $tns_alias $logdir $cfgdir
			while true; do
				echo
				read -p "Besides the FMW/JRF schemas, are you willing to export additional custom schemas?: " yn2
				case $yn2 in
                			[Yy]* )
						read -p "Provide the list of custom schemas separated by a space (for example CUST1 CUST2 CUST3): " list_cust_schemas
						echo "Will export both FMW and custom schemas..."
						export complete_schema_list="${rcu_schema_list}"$'\n'"${list_cust_schemas}"
						echo $list_cust_schemas >$cfgdir/custom_schema_list.cfg
						break;;
					[Nn]* )
                        			echo "Will export  only FMW schemas..."
						export complete_schema_list="$rcu_schema_list"
						break;;
					* ) echo "Please answer y or n.";;
                 		esac
			done
			break;;
                [Nn]* ) 
			echo "Will export only custom schemas..."
			read -p "Provide the list of custom schemas separated by a space (for exmaple CUST1 CUST2 CUST3): " list_cust_schemas
			export complete_schema_list="$list_cust_schemas"
			break;;

                * ) echo "Please answer y or n.";;
                 esac
done
echo $complete_schema_list > ${cfgdir}/complete_schema_list.cfg
echo "*********************************************************************************"
echo "COMPLETE LIST OF SCHEMAS TO BE EXPORTED: "
echo "$complete_schema_list"
echo "*********************************************************************************"

#EXPORT AND DDL FOR ALL SCHEMAS
for schema in $complete_schema_list;do
	echo "*********************************************************************************"
	echo "Starting export and ddl operations for schema $schema."
	echo "Granting $schema access to the data pump directory and retrieving role DDL..."
	sqlplus -s sys/""${sys_pass}""@${tns_alias} as sysdba >  $logdir/${schema}_ddl.log << EOF
	GRANT READ,WRITE ON DIRECTORY $dumpdirname TO $schema;
	GRANT SELECT ON "SYSTEM"."SCHEMA_VERSION_REGISTRY" TO "${schema}";
	$beautify
	spool ${schemasdir}/create_schema_${schema}.sql
	SELECT DBMS_METADATA.GET_DDL('USER', '${schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT', '${schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT','${schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT', '${schema}') FROM dual;
	spool off
	exit
EOF
	check_connection $schema $tns_alias
	echo
	echo "Initiating export for schema ${schema}."
	echo "Please check log at ${logdir}/${schema}_export.log."
	waiting &
	waitpid=$!
	expdp ${schema}/"${schema_pass}"@${tns_alias} schemas=${schema} directory="$dumpdirname" dumpfile=${schema}_export.dmp logfile=${schema}.dmplog PARALLEL=1 CLUSTER=N encryption_password=${schema_pass} FLASHBACK_SCN=$scn > ${logdir}/${schema}_export.log 2>&1;
	#Workaround for bug where UMS schema does not have procedure grants
	echo "GRANT CREATE PROCEDURE TO $schema ;" >> ${schemasdir}/create_schema_${schema}.sql
	#Excluding BUFFERED messages view grants cause IDS will be inalid on import
	cat ${schemasdir}/create_schema_${schema}.sql|  egrep -v "(QT.+BUFFER)" >>${dumpdir}/create_all_schemas.sql
	kill $waitpid
	wait $waitpid > /dev/null 2>&1
	echo "Export and DDL extraction for schema $schema complete!"
	echo "*********************************************************************************"
done


#CONSTRUCT IN QUERY
for schema in $complete_schema_list;do
    inquery+="'${schema}',"
done
inquery="${inquery%?}"
total_in_query="($inquery)"

echo
#GET TABLESPACES
echo "Obtaining tablespaces' DDL..."
waiting &
waitpid=$!

sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba >  ${logdir}/tablespaces_list_query.log << EOF
$beautify
spool ${cfgdir}/tablespaces_list.cfg
select DISTINCT tablespace_name from dba_segments WHERE OWNER in $total_in_query;
select DISTINCT temporary_tablespace from dba_users WHERE username in $total_in_query;
spool off
exit
EOF
export tablespaces_list=$(cat $cfgdir/tablespaces_list.cfg)
for tablespace in $tablespaces_list;do
        sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba >  $logdir/${tablespace}_ddl.log << EOF
        $beautify
        spool ${tablespacesdir}/create_tablespace_${tablespace}.sql
        SELECT DBMS_METADATA.GET_DDL('TABLESPACE','${tablespace}') FROM DUAL;
        spool off;
EOF
	cat ${tablespacesdir}/create_tablespace_${tablespace}.sql  >>$dumpdir/create_all_tablespaces.sql
done
kill $waitpid
wait $waitpid > /dev/null 2>&1


#GET QUEUES
echo "Obtaining list of queues..."
waiting &
waitpid=$!

sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba >  ${logdir}/queue_list_query.log << EOF
$beautify
spool ${cfgdir}/queue_list.cfg
select owner || '.' || name from dba_queues where  owner in $total_in_query;
spool off
exit
EOF
export queue_list=$(cat  ${cfgdir}/queue_list.cfg)
kill $waitpid
wait $waitpid > /dev/null 2>&1

#GET Role DDL
echo "Obtaining list of roles..."
waiting &
waitpid=$!

sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba > ${logdir}/roles_list_query.log << EOF
$beautify
spool $cfgdir/role_list.cfg
select DISTINCT role from dba_roles;
spool off;
EOF
export roles_list=$(cat $cfgdir/role_list.cfg)
for role in $roles_list;do
        sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba  >  $logdir/${schema}_role.log << EOF
	$beautify
        spool ${rolesdir}/create_role_${role}.sql
        SELECT DBMS_METADATA.GET_DDL('ROLE','${role}') FROM DUAL;
        spool off;
	exit
EOF
done
for role in $roles_list;do
        cat ${rolesdir}/create_role_${role}.sql  >>$dumpdir/create_all_roles.sql
done

kill $waitpid
wait $waitpid > /dev/null 2>&1


#Clean up dirt in sql code
sed -i '/ERROR/d' ${dumpdir}/create_all_*.sql
sed -i '/no rows/d' ${dumpdir}/create_all_*.sql
sed -i '/ORA-/d' ${dumpdir}/create_all_*.sql
sed -i '/Help/d' ${dumpdir}/create_all_*.sql
sed -i 's/; ALTER/;\n ALTER/g' ${dumpdir}/create_all_*.sql
cd $dumpdir
echo "Creating package with all artifacts..."
tar -czf  $dumpdir/complete_export_ddl_${dt}.tgz ./*

echo ""
echo ""
echo "*********************************************************************************"
echo "************************************* DONE! *************************************"
echo "*********************************************************************************"
echo
echo "--RESULTS AT:"
echo "$dumpdir"

echo "--CHECK LOGS AT:"
echo "$logdir"

echo "--FULL ZIP TO TRANSFER FOR RESTORE:"
echo "$dumpdir/complete_export_ddl_${dt}.tgz"
echo
echo "*********************************************************************************"
echo "*********************************************************************************"

echo
echo


