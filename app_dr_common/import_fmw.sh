#!/bin/bash
export dt=`date +%y-%m-%d-%H-%M-%S`
export prefix=$1
export passwd=$2
export tns_alias=$3
export dumpdir=$4

export schema_list=$(cat $dumpdir/schema_list.log)


#export logdir=/tmp
#Alternatively, and as a better approach, create an instance-specific service and an alias for it in tnsnames.ora. Pending to be automated
: '
[oracle@drdbrac12a1 ~]$ srvctl add service -db $ORACLE_UNQNAME -service export_soaedg.example.com -preferred  SOADB231 -pdb SOADB23_pdb1
[oracle@drdbrac12a1 ~]$ srvctl start service -s  export_soaedg.example.com -db $ORACLE_UNQNAME
[oracle@drdbrac12a1 ~]$ lsnrctl status | grep export_soaedg.example.com
Service "export_soaedg.example.com" has 1 instance(s).
[oracle@drdbrac12a1 ~]$ cat /u01/app/oracle/product/23.0.0.0/dbhome_1/network/admin/tnsnames.ora | grep export
EXPORT_SOADB23_PDB1=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=drdbrac12a-scan.dbsubnet.vcnlon80.oraclevcn.com)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=export_soaedg.example.com)(FAILOVER_MODE=(TYPE=select)(METHOD=basic))))
'

mkdir -p $dumpdir
cd $dumpdir

#SYS generic ops
echo "Creating import dir and role for reg access"
sqlplus sys/""${passwd}""@${tns_alias} as sysdba << EOF
DROP DIRECTORY DUMP_INFRA;
CREATE DIRECTORY DUMP_INFRA AS '$dumpdir';
GRANT READ,WRITE ON DIRECTORY DUMP_INFRA TO SYS;
BEGIN EXECUTE IMMEDIATE 'CREATE ROLE REGISTRYACCESS'; END;
BEGIN     EXECUTE IMMEDIATE 'CREATE ROLE STBROLE'; END;
BEGIN     EXECUTE IMMEDIATE 'CREATE ROLE FMW_RO'; END;
set line 500;
column directory_name format a30;
column directory_path format a60;
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name='DUMP_INFRA';
EOF

echo "Creating tablespaces, creating schemas and assigning roles..."
sqlplus sys/""${passwd}""@${tns_alias} as sysdba << EOF
@$dumpdir/create_all_tablespaces.sql;
@$dumpdir/create_all_roles.sql;
@$dumpdir/create_all_schemas.sql;
EOF

echo "Importing SCHEMA REGISTRY INFO"

impdp  \"sys/"${passwd}"@${tns_alias} as sysdba\" SCHEMAS=SYSTEM directory=DUMP_INFRA DUMPFILE=SYSTEM_SCHEMA_VERSION_REGISTRY.dmp LOGFILE=SYSTEM_SCHEMA_VERSION_REGISTRY_import.log PARALLEL=1 CLUSTER=N encryption_password=$passwd TABLE_EXISTS_ACTION=APPEND
impdp  \"sys/"${passwd}"@${tns_alias} as sysdba\"  SCHEMAS=$schema_list directory=DUMP_INFRA DUMPFILE=SYSTEM_SCHEMA_VERSION_REGISTRY.dmp LOGFILE=SYSTEM_SCHEMA_VERSION_REGISTRY_import_schemas.log parallel=1 TABLE_EXISTS_ACTION=APPEND

#Initial grants to schemas
echo "Assigning tablespace and dump dir rights to schemas..."
for schema in $schema_list;do
        echo "Updating schema rights for $schema..."
        sqlplus sys/""${passwd}""@${tns_alias} as sysdba << EOF
        GRANT READ,WRITE ON DIRECTORY DUMP_INFRA TO $schema;
        GRANT UNLIMITED TABLESPACE TO $schema;
        GRANT SELECT ON "SYSTEM"."SCHEMA_VERSION_REGISTRY" TO "${schema}";
EOF
done
echo "Real Schema list : $real_schema_list"

echo "Importing schemas exports..."
for schema in $schema_list;do
        echo "Importing $schema..."
	impdp ${schema}/"${passwd}"@${tns_alias} schemas=${schema} directory=DUMP_INFRA dumpfile=${schema}_export.dmp logfile=${schema}_import.log PARALLEL=1 CLUSTER=N encryption_password=$passwd;
done

echo "Re-assign roles to consolidate"
sqlplus sys/""${passwd}""@${tns_alias} as sysdba << EOF
@$dumpdir/create_all_schemas.sql;
EOF

echo "*********************************************************************************"
echo "************************************* DONE! *************************************"
echo "*********************************************************************************"

