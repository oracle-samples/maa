#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to create OIG schemas

ORACLE_HOME=<OIG_ORACLE_HOME>
DB_HOST=<OIG_DB_SCAN>
DB_PORT=<OIG_DB_LISTENER>
DB_SERVICE=<OIG_DB_SERVICE>
RCU_PREFIX=<OIG_RCU_PREFIX>
SYS_PWD="<OIG_DB_SYS_PWD>"
RCU_PWD="<OIG_DB_SCHEMA_PWD>"
OIG_SCHEMAS=" -component MDS -component IAU -component SOAINFRA -component IAU_APPEND -component IAU_VIEWER -component OPSS -component WLS -component STB -component OIM -component UCSUMS"
printf "$SYS_PWD\n" > /tmp/pwd.txt
printf "$RCU_PWD\n" >> /tmp/pwd.txt

$ORACLE_HOME/oracle_common/bin/rcu -silent -createRepository -databaseType ORACLE  -connectString $DB_HOST:$DB_PORT/$DB_SERVICE  -dbUser sys -dbRole sysdba -selectDependentsForComponents true -useSamePasswordForAllSchemaUsers true -schemaPrefix $RCU_PREFIX  $OIG_SCHEMAS  -f < /tmp/pwd.txt
