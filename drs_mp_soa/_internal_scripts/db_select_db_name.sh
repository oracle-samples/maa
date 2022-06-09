#!/bin/bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
echo "set feed off
set pages 0
select value from V\$PARAMETER where NAME='db_name';
exit
"  | sqlplus -s / as sysdba