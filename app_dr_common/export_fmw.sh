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
###      	./export_fmw.sh [RCU_PREFIX] [RCU_PASSWORD] [SYS_PASSWORD] [TNS_ALIAS] [EXPORT_DIRECTORY]
### Where:
###		RCU_PREFIX:
###			Prefix used for schemas when the FMW RCU was used to create the Database artifacts used by a FMW domain
###             RCU_PASSWORD:
###                     Password provided for schemas when FMW RCU was executed to create the Database artifacts used by a FMW domain.
###			Do not enclose passwords in double quotes (").
###		SYS_PASSWORD:
###			User sys's password in the PDB hosting the FMW systems.
###                     Do not enclose passwords in double quotes (").
###		TNS_ALIAS:
###			Alias in tnsnames.ora that identifies the connect string to be used for the export
###		EXPORT_DIRECTORY:
###			Directory where exports and ddl will be created
if [[ $# -eq 5 ]];
then
	export dt=`date +%y-%m-%d-%H-%M-%S`
	export prefix=$1
	export schema_pass=$2
	export sys_pass=$3
	export tns_alias=$4
	export dumpdir=$5/FMW_EXPORTS_${dt}/
	export logdir="$dumpdir"
else
	echo ""
    	echo "ERROR: Incorrect number of parameters used: Expected 5, got $#"
    	echo ""
    	echo "Usage:"
    	echo "    $0 [RCU_PREFIX] [RCU_PASSWORD] [SYS_PASSWORD] [TNS_ALIAS] [EXPORT_DIRECTORY]"
    	echo ""
    	echo "Example:  "
    	echo "    $0 FMW1412 myrcupasswd123 mysyspasswd123 EXPORT_SOADB23_PDB1 /u01/dbdataexports "
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

mkdir -p $dumpdir
cd $dumpdir
#SYS generic ops
sqlplus -s sys/""${sys_pass}""@${tns_alias} as sysdba > $dumpdir/schema_list_query.log << EOF
DROP DIRECTORY DUMP_INFRA;
CREATE DIRECTORY DUMP_INFRA AS '$dumpdir';
GRANT READ,WRITE ON DIRECTORY DUMP_INFRA TO SYS;
set line 500;
column directory_name format a30;
column directory_path format a60;
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name='DUMP_INFRA';
set feedback off;
column aaa format a1000;
set echo off;
set head off;
set termout off;
spool ON
spool ${dumpdir}/schema_list.log
select OWNER from SYSTEM.SCHEMA_VERSION_REGISTRY where OWNER like '${prefix}\_%' escape '\';
spool off

EOF

export schema_list=$(cat schema_list.log)

# Pending to add logic that handles placing ERRORS in the DDl when object does not exist


#Schema DDL
for schema in $schema_list;do
	echo "Updating schema rights for $schema (access data pump directory and schema_registry)..."
	echo "Retrieving DDL for ${schema} ..."
	sqlplus -s sys/""${sys_pass}""@${tns_alias} as sysdba >  $dumpdir/${schema}_ddl.log << EOF
	GRANT READ,WRITE ON DIRECTORY DUMP_INFRA TO $schema;
	GRANT SELECT ON "SYSTEM"."SCHEMA_VERSION_REGISTRY" TO "${schema}";
	$beautify
	spool ${dumpdir}/create_schema_${schema}.sql
	SELECT DBMS_METADATA.GET_DDL('USER', '${schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT', '${schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT','${schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT', '${schema}') FROM dual;
	spool off
EOF
	echo "Initiating export for scchema '${schema}..."
	expdp ${schema}/"${schema_pass}"@${tns_alias} schemas=${schema} directory=DUMP_INFRA dumpfile=${schema}_export.dmp logfile=${schema}_export.log PARALLEL=1 CLUSTER=N encryption_password=${schema_pass};
done

#Excluding BUFFERED messages view grants cause IDS will be inalid on import
for schema in $schema_list;do
	cat ${dumpdir}/create_schema_${schema}.sql|  egrep -v "(QT.+BUFFER)" >>${dumpdir}/create_all_schemas.sql
done

#Using param file to avoid parsing errors with query

cat << EOF > $dumpdir/sysparam.cfg
SCHEMAS=system 
INCLUDE=VIEW:"IN('SCHEMA_VERSION_REGISTRY')" 
TABLE:"IN('SCHEMA_VERSION_REGISTRY$')"
directory=DUMP_INFRA 
dumpfile=SYSTEM_SCHEMA_VERSION_REGISTRY.dmp 
logfile=SYSTEM_SCHEMA_VERSION_REGISTRY.log 
CLUSTER=N 
encryption_password="$sys_pass"
QUERY=SYSTEM.SCHEMA_VERSION_REGISTRY$:"where OWNER like '${prefix}|_%' escape'|'" 
EOF
expdp \"sys/"${sys_pass}"@${tns_alias} as sysdba\" parfile=$dumpdir/sysparam.cfg

#Role DDL
(
sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba << EOF
$beautify
select DISTINCT role from dba_roles;
EOF
) | grep -v 'rows' | awk '{print $1}' > $dumpdir/role_list.log

export roles_list=$(cat $dumpdir/role_list.log)

for role in $roles_list;do
        sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba  >  $dumpdir/${schema}_role.log << EOF
	$beautify
        spool ${dumpdir}/create_role_${role}.sql
        SELECT DBMS_METADATA.GET_DDL('ROLE','${role}') FROM DUAL;
        spool off;
EOF
done

for role in $roles_list;do
        cat ${dumpdir}/create_role_${role}.sql  >>$dumpdir/create_all_roles.sql
done

# Tablespace DDL

(
sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba << EOF
$beautify
select DISTINCT tablespace_name from dba_segments WHERE OWNER like '${prefix}\_%' escape '\';
select DISTINCT temporary_tablespace from dba_users WHERE username like '${prefix}\_%' escape '\';
EOF
) | grep -v 'OWNER' |grep -v 'rows' | awk '{print $1}' > $dumpdir/tablespaces_list.log

export tablespaces_list=$(cat $dumpdir/tablespaces_list.log)

for tablespace in $tablespaces_list;do
        sqlplus -s  sys/""${sys_pass}""@${tns_alias} as sysdba >  $dumpdir/${tablespace}_ddl.log << EOF
	$beautify
        spool ${dumpdir}/create_tablespace_${tablespace}.sql
        SELECT DBMS_METADATA.GET_DDL('TABLESPACE','${tablespace}') FROM DUAL;
	spool off;
EOF
done

for tablespace in $tablespaces_list;do
        cat ${dumpdir}/create_tablespace_${tablespace}.sql  >>$dumpdir/create_all_tablespaces.sql
done

#Clean up dirt in sql code
sed -i '/ERROR/d' ${dumpdir}/create_all_*.sql
sed -i '/no rows/d' ${dumpdir}/create_all_*.sql
sed -i '/ORA-/d' ${dumpdir}/create_all_*.sql
sed -i '/Help/d' ${dumpdir}/create_all_*.sql
sed -i 's/; ALTER/;\n ALTER/g' ${dumpdir}/create_all_*.sql
sed -i "s/$sys_pass/****/g" ${dumpdir}/sysparam.cfg
cd $dumpdir
tar -czf  $dumpdir/complete_export_ddl_${dt}.tgz ./*

echo ""
echo ""

echo "************************************* DONE! *************************************"
echo "Results at:  $dumpdir"
echo "Full zip at: $dumpdir/complete_export_ddl_${dt}.tgz"
echo "*********************************************************************************"
