#!/bin/bash

## fmwadbs_runsqlquery_nosqlplus.sh  script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# This script can be used to execute any SQL query passsed in the command line as argument in the ADBS used by FMW
# Queries are executed as ADMIN user(ADBS)
# The script uses com.ziclix.python.sql pakage and triggers a temporary script execution from wlstr
# It uses the connect string and values in an exsiting WLS datasources (passed also as parameter) under $DOMAIN_HOME}/config/jdbc
# Notice that typical escape char precautions are required for the query 

### Usage:
###  The script can be executed with 2 or 3 params
###
###	Executing with 2 parameters:
###     -The first parameter is the datasource file that will be used for connection information
###     -The second parameter is the sql query to be executed
###     -The username and password will be retrived from the datasorce
###		Usage with 2 parameters
###			./fmwadbs_runsqlquery_nosqlplus.sh DATASOURCE_FILE SQL_QUERY
### 		Where:
###			DATASOURCE_FILE    The jdbc datasource file (including ocmplete path)
###			SQL_QUERY          The sql statement to be executed 
###
###		Example:
###			 ./fmwadbs_runsqlquery_nosqlplus.sh '/u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml' 'select count(*) from JPS_ATTRS'
###
###     Executing with 3 parameters:
###	-The first parameter is the datasource file that will be used for connection information
###	-The second parameter will be the sql query to be executed
###	-ADMIN will be used as user and the 3rd parameter will be its password
###             Usage with 3 parameters
###                     ./fmwadbs_runsqlquery_nosqlplus.sh DATASOURCE_FILE SQL_QUERY ADMIN_PASSWORD
###		Where:
###                     DATASOURCE_FILE		The jdbc datasource file (including ocmplete path)
###                     SQL_QUERY		The sql statement to be executed
###			ADMIN_PASSWORD		The ADMIN user's password
###
###             Example:
###			 ./fmwadbs_runsqlquery_nosqlplus.sh '/u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml' 'select value from v\$parameter where name=\'cluster_database\' admin_password123"


export datasource_file="$1"
export sql_query="$2"
export exec_path=$(dirname "$0")

if [[ $# -eq 3 ]]; then
	export username="ADMIN"
	export password=$3
elif [[ $# -eq 2 ]]; then
	export username=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'user')
	export enc_password=$(cat $datasource_file | grep  "<password-encrypted>" | awk -F'<password-encrypted>' '{print $2}' | awk -F'</password-encrypted>' '{print $1}')
	export password=$($exec_path/fmwadbs_dec_pwd.sh $enc_password)
	echo "Using pasword = $password"

else
	echo ""
	echo "ERROR: Incorrect number of parameters used. The script can be executed with 2 or 3 params, got $#"
	echo "************Executing with 2 parameters:************"
	echo "  -The first parameter is the datasource file that will be used for connection information"
	echo "  -The second parameter is the sql query to be executed"
	echo "  -The username and password will be retrived from the datasorce"
	echo "Usage :"
        echo "    $0  DATASOURCE_FILE SQL_QUERY"
	echo "Example:  "
        echo "    $0 '/u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml' 'select count(*) from JPS_ATTRS'"
	echo "************Executing with 3 parameters************"
	echo "	-The first parameter is the datasource file that will be used for connection information"
	echo "	-The second parameter will be the sql query to be executed"
	echo "	-ADMIN will be used as user and the 3rd parameter will be its password"
	echo "Usage :"
	echo "    $0  DATASOURCE_FILE SQL_QUERY ADMIN_PASSWORD"
	echo "Example:  "
	echo "    $0 '/u01/data/domains/my_domain/config/jdbc/opss-datasource-jdbc.xml' 'select value from v\$parameter where name=\'cluster_database\' password"
	echo ""
	echo "Please make sure appropriate escape chars are added when needed in sql statements (for example before $ and ')"
	exit 1
fi


execute_query(){
	echo ""
	echo "Executing query $sql_query through wlst..."
	echo "from com.ziclix.python.sql import zxJDBC" > /tmp/query_execute.py
	echo "from java.lang import System" >> /tmp/query_execute.py
	echo "System.setProperty('oracle.net.tns_admin','$oracle_net_tns_admin');" >> /tmp/query_execute.py
	echo "System.setProperty('javax.net.ssl.trustStore','$javax_net_ssl_trustStore');" >> /tmp/query_execute.py
	echo "System.setProperty('javax.net.ssl.trustStoreType','$javax_net_ssl_trustStoreType');" >> /tmp/query_execute.py
	echo "System.setProperty('javax.net.ssl.trustStorePassword','$javax_net_ssl_trustStorePassword');" >> /tmp/query_execute.py
	echo "System.setProperty('javax.net.ssl.keyStore','$javax_net_ssl_keyStore') " >> /tmp/query_execute.py
	echo "System.setProperty('javax.net.ssl.keyStorePassword','$javax_net_ssl_keyStorePassword')" >> /tmp/query_execute.py
	echo "jdbc_url = '$jdbc_url' " >> /tmp/query_execute.py
	echo "username = \"$username\" " >> /tmp/query_execute.py
	echo "password = \"$password\" " >> /tmp/query_execute.py
	echo "driver = \"oracle.jdbc.xa.client.OracleXADataSource\" " >> /tmp/query_execute.py
	echo "conn = zxJDBC.connect(jdbc_url, username, password, driver)" >> /tmp/query_execute.py
	echo "cursor = conn.cursor(1)" >> /tmp/query_execute.py
	printf '%s\n' "cursor.execute(\" $sql_query \")" >> /tmp/query_execute.py
	#echo "cursor.execute(\"${sql_query}\")" >> /tmp/query_execute.py
	echo "print cursor.fetchone()" >> /tmp/query_execute.py
	export result=$($MIDDLEWARE_HOME/oracle_common/common/bin/wlst.sh /tmp/query_execute.py | tail -1)
	echo "The complete result of executing query $sql_query is: $result"
	export trimmed_result=$(echo "${result//[$'\t\r\n ']}")
	echo "The trimmed result  (first item) of executing query $sql_query is: $trimmed_result"
}

gather_variables_from_DS() {
	echo "Getting variables from the $datasource_file datasource"
	export connect_string=$($exec_path/fmwadbs_get_connect_string.sh $datasource_file)
	export jdbc_url="jdbc:oracle:thin:@"${connect_string}
	export oracle_net_tns_admin=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'oracle.net.tns_admin')
	export javax_net_ssl_trustStore=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'javax.net.ssl.trustStore')
	export javax_net_ssl_trustStoreType=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'javax.net.ssl.trustStoreType')
	export javax_net_ssl_trustStorePassword=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'javax.net.ssl.trustStorePassword')
	export javax_net_ssl_keyStore=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'javax.net.ssl.keyStore')
	export javax_net_ssl_keyStorePassword=$($exec_path/fmwadbs_get_ds_property.sh $datasource_file 'javax.net.ssl.keyStorePassword')
	echo "oracle.net.tns_admin=$oracle_net_tns_admin"
}

gather_variables_from_DS
execute_query
