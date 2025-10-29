#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of procedures used to Drop OAM Schemas
#
ORACLE_HOME=<OAM_ORACLE_HOME>
DB_HOST=<OAM_DB_SCAN>
DB_PORT=<OAM_DB_LISTENER>
DB_SERVICE=<OAM_DB_SERVICE>
RCU_PREFIX=<OAM_RCU_PREFIX>
SYS_PWD="<OAM_DB_SYS_PWD>"
RCU_PWD="<OAM_DB_SCHEMA_PWD>"
OAM_SCHEMAS=" -component MDS -component IAU -component IAU_APPEND -component IAU_VIEWER -component OPSS -component WLS -component STB -component OAM "
echo $SYS_PWD > /tmp/pwd.txt

$ORACLE_HOME/oracle_common/bin/rcu -silent -dropRepository -databaseType ORACLE  -connectString $DB_HOST:$DB_PORT/$DB_SERVICE \ -dbUser sys -dbRole sysdba -selectDependentsForComponents true \ -schemaPrefix $RCU_PREFIX \ $OAM_SCHEMAS \ -f < /tmp/pwd.txt
