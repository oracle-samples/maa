#!/bin/bash

## import_fmw.sh script version 1.0.
##
## Copyright (c) 2025 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates a packed extraction of the required tablespaces, schemas and roles used by Oracle FMW
### It uses Oracle Data Pump Export and DDL extraction from a PDB hosting a FMW system (typically JRF or SOA domain)
### to create a tar that can be transferred to another database system to "migrate" the original FMW domain.
### It can move a FMW system to a different PDB or a totally different database (ideally in a PDB hosted by a  multitenant database.
### - It identifies the schemas based on the prefix provided in the Repository Creation Utility (RCU).
### - The precise list of schemas exported is configured in the script's variable "schema_list"- The default value provided
### for this variable is the on required to export a standard EDG FMW SOA on prem system.
### - It requires a tns alias mapping to a service (attached to a single instance in RAC configuration) to conect to the precise PDB.
### Create an instance-specific service and an alias for it in tnsnames.ora. Pending to be automated. For example:
### [oracle@drdbrac12a1 ~]$ srvctl add service -db $ORACLE_UNQNAME -service export_soaedg.example.com -preferred  SOADB231 -pdb SOADB23_pdb1
### [oracle@drdbrac12a1 ~]$ srvctl start service -s  export_soaedg.example.com -db $ORACLE_UNQNAME
### [oracle@drdbrac12a1 ~]$ lsnrctl status | grep export_soaedg.example.com
### Service "export_soaedg.example.com" has 1 instance(s).
### [oracle@drdbrac12a1 ~]$ cat /u01/app/oracle/product/23.0.0.0/dbhome_1/network/admin/tnsnames.ora | grep export
### EXPORT_SOADB23_PDB1=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=drdbrac12a-scan.dbsubnet.vcnlon80.oraclevcn.com)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=export_soaedg.example.com)(FAILOVER_MODE=(TYPE=select)(METHOD=basic))))
### - It assumes same password in the PDB for the sys user and schema, but can be easily customized with the schema_pass variable
### Usage:
###
###      	./export_fmw.sh [RCU_PREFIX] [SYS_PASSWORD] [TNS_ALIAS] [EXPORT_DIRECTORY]
### Where:
###		RCU_PREFIX:
###			Prefix used for schemas when the FMW RCU was used to create the Database artifacts used by a FMW domain
###		SYS_PASSWORD:
###			User sys's password in the PDB hosting the FMW systems
###		TNS_ALIAS:
###			Alias in tnsnames.ora that identifies the connect string to be used for the export
###		EXPORT_DIRECTORY:
###			Directory where exports and ddl will be created

export dt=`date +%y-%m-%d-%H-%M-%S`
export prefix=$1
export passwd=$2
export tns_alias=$3
export dumpdir=$4/FMW_EXPORTS_${dt}/
export logdir="$dumpdir"

export schema_pass=$passwd
#Schemas para SOA Cloud
#export schema_list="WLS UMS IAU OPSS ESS SOAINFRA IAU_APPEND IAU_VIEWER WLS_RUNTIME STB MDS DBFS MFT"

#Schemas para SOA on-prem
export schema_list="WLS UMS IAU OPSS SOAINFRA IAU_APPEND IAU_VIEWER WLS_RUNTIME STB MDS"

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
set head off;
set termout off;
set longchunksize 100000;
exec DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', FALSE);
exec DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
"

mkdir -p $dumpdir
cd $dumpdir
#SYS generic ops
sqlplus sys/""${passwd}""@${tns_alias} as sysdba << EOF
DROP DIRECTORY DUMP_INFRA;
CREATE DIRECTORY DUMP_INFRA AS '$dumpdir';
GRANT READ,WRITE ON DIRECTORY DUMP_INFRA TO SYS;
set line 500;
column directory_name format a30;
column directory_path format a60;
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name='DUMP_INFRA';
EOF


# Pending to add logic that handles placing ERRORS in the DDl when object does not exist

#Schema DDL
for schema in $schema_list;do
        real_schema="$prefix"_"$schema"
	real_schema_list+="$real_schema "
        echo "Updating schema rights for $real_schema..."
	sqlplus -s sys/""${passwd}""@${tns_alias} as sysdba << EOF
	GRANT READ,WRITE ON DIRECTORY DUMP_INFRA TO $real_schema;
	GRANT SELECT ON "SYSTEM"."SCHEMA_VERSION_REGISTRY" TO "${real_schema}";
	$beautify
	spool ${dumpdir}/create_schema_${real_schema}.sql
	SELECT DBMS_METADATA.GET_DDL('USER', '${real_schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT', '${real_schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT','${real_schema}') FROM dual;
	SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT', '${real_schema}') FROM dual;
	spool off
EOF

	expdp ${real_schema}/"${schema_passwd}"@${tns_alias} schemas=${real_schema} directory=DUMP_INFRA dumpfile=${real_schema}_export.dmp logfile=${real_schema}_export.log PARALLEL=1 CLUSTER=N encryption_password=$passwd;
done
echo "$real_schema_list">${dumpdir}/schema_list.log

#Excluding BUFFERED messages view grants cause IDS will be inalid on import
for schema in $real_schema_list;do
	cat ${dumpdir}/create_schema_${real_schema}.sql|  egrep -v "(QT.+BUFFER)" >>${dumpdir}/create_all_schemas.sql
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
encryption_password="$passwd"
QUERY=SYSTEM.SCHEMA_VERSION_REGISTRY$:"where OWNER like '${prefix}%'" 
EOF
expdp \"sys/"${passwd}"@${tns_alias} as sysdba\" parfile=$dumpdir/sysparam.cfg

#Role DDL
(
sqlplus -s  sys/""${passwd}""@${tns_alias} as sysdba << EOF
$beautify
select DISTINCT role from dba_roles;
EOF
) | grep -v 'rows' | awk '{print $1}' > $dumpdir/role_list.log

export roles_list=$(cat $dumpdir/role_list.log)

for role in $roles_list;do
        sqlplus -s  sys/""${passwd}""@${tns_alias} as sysdba << EOF
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
sqlplus -s  sys/""${passwd}""@${tns_alias} as sysdba << EOF
$beautify
select DISTINCT tablespace_name from dba_segments WHERE OWNER like '${prefix}%';
select DISTINCT temporary_tablespace from dba_users WHERE username like '${prefix}%';
EOF
) | grep -v 'OWNER' |grep -v 'rows' | awk '{print $1}' > $dumpdir/tablespaces_list.log

export tablespaces_list=$(cat $dumpdir/tablespaces_list.log)

for tablespace in $tablespaces_list;do
        sqlplus -s  sys/""${passwd}""@${tns_alias} as sysdba << EOF
	$beautify
        spool ${dumpdir}/create_tablespace_${tablespace}.sql
        SELECT DBMS_METADATA.GET_DDL('TABLESPACE','${tablespace}') FROM DUAL;
	spool off;
EOF
done

for tablespace in $tablespaces_list;do
        cat ${dumpdir}/create_tablespace_${tablespace}.sql  >>$dumpdir/create_all_tablespaces.sql
done

#Clean up dirt sql code
sed -i '/ERROR/d' ${dumpdir}/create_all_*.sql
sed -i '/no rows/d' ${dumpdir}/create_all_*.sql
sed -i '/ORA-/d' ${dumpdir}/create_all_*.sql
sed -i '/Help/d' ${dumpdir}/create_all_*.sql
sed -i 's/; ALTER/;\n ALTER/g' ${dumpdir}/create_all_*.sql

cd $dumpdir
tar -czf  $dumpdir/complete_export_ddl.tgz ./*

echo "************************************* DONE! *************************************"
echo "Results at:  $dumpdir"
echo "Full zip at: $dumpdir/complete_export_ddl.tgz"
echo "*********************************************************************************"
