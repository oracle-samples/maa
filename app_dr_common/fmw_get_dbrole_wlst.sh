#!/bin/bash

## fmw_get_dbrole_wlst.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

## This script can be used to get the role of the database

## The script uses com.ziclix.python.sql package and triggers a temporary script execution from wlstr
## It uses the connect string and values passed as parameter

### Usage:
### ./fmw_get_dbrole_wlst.sh USERNAME PASSWORD JDBC_URL
###
### Example:
### ./fmw_get_dbrole_wlst.sh 'sys' 'mypassword' 'jdbc:oracle:thin:@dbhost-scan.dbsubnet.myvcn.oraclevcn.com:1521/PDB1.dbsubnet.myvcn.oraclevcn.com'
### 

export username="$1"
export password="$2"
export jdbc_url="$3"

if  [[ ${username} = "sys" || ${username} = "SYS"  ]]; then
	username="sys as sysdba"
fi

execute_query(){
        echo "from com.ziclix.python.sql import zxJDBC" > /tmp/get_db_role.py
        echo "jdbc_url = \"$jdbc_url\" " >> /tmp/get_db_role.py
        echo "username = \"$username\" " >> /tmp/get_db_role.py
        echo "password = \"$password\" " >> /tmp/get_db_role.py
        echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/get_db_role.py
        echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/get_db_role.py
        echo "cursor = conn.cursor(1)" >> /tmp/get_db_role.py
	echo "cursor.execute(\"select database_role from v\$database\")" >> /tmp/get_db_role.py
        echo "print cursor.fetchone()" >> /tmp/get_db_role.py
        export result=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/get_db_role.py | tail -1)
        echo "${result}"
}

execute_query

