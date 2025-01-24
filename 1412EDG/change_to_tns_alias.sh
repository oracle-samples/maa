#!/bin/bash

## change_to_tns_alias.sh script version 1.0.
##
## Copyright (c) 2025 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### -This script prequires restart of the Administration and Managed servers to take effect and performs replacements in
### the WLS configuration files, so it must be used conscientiously.
### -This script can be used to replace traditional JDBC connect strings with a TNS ALIAS:
###	1.- It creates a tnsnames.ora file using the current connect string used by OPSS (uses a date-based name for the alias).
###	2.- It deploys a DBCLient module with the created tnsnames.ora.
###	3.- It replaces connect strings with the alias and adds the required tns_admin property to datasources (All the connect 
### 	strings used by WLS datasources (under $DOMAIN_HOME}/config/jdbc) and jps config files (under ${DOMAIN_HOME}/config/fmwconfig) 
### -It assumes that no previous alias/tns_admin have been set in the domain.
### -The script uses the scripts fmw_get_ds_property.sh and fmw_get_connect_string.sh so make sure to place them in the same directory as this script
### These auxiliarry script can be obtained from https://github.com/oracle-samples/maa/tree/main/app_dr_common
### -The WLS domain-specific variables listed below need to be customized before executing the script.
### Usage:
###	./change_to_tns_alias.sh [DOMAIN_PASS] [KEYPASS]
### Where:
###		DOMAIN_PASS:
###			 The password for the admin user that will update the domain.
###		KEYPASS:
###			Password used to access the TustTore file configured for the domain.
###
### EXAMPLE:
### ./change_to_tns_alias.sh  domainadminpassword123 mycertkeystorepass123


################# CUSTOMIZE THESE VARIABLES ACORDING TO YOUR ENVIRONMENT #################
export DOMAIN_HOME=/u01/oracle/config/domains/soa1412rc2edg
export MW_HOME=/u01/oracle/products/fmw
export ADMINVHN=asvip.soaedgtest.paasmaaoracle.com
export ADMINPORT=9002
export DOMAINUSER=soaedg1412rc2admin
export TRUSTSTOREFILE=/u01/oracle/config/keystores/appTrustKeyStore.pkcs12
######################END OF VARIABLE CUSTOMIZATION ######################################


if [[ $# -eq 2 ]];
then
	export DOMAINPASS=$1
	export KEYPASS=$2

else
	echo ""
	echo "ERROR: Incorrect number of parameters used: Expected 2, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [DOMAINPASS] [KEYPASS]"
	echo ""
	echo "Example:  "
	echo "    $0 domainadminpassword123 mycertkeystorepass123"
	exit 1
fi

export date_label=$(date '+%d-%m-%Y-%H-%M-%S')
export tns_alias=EDGTNSA_${date_label}
export datasource_name=opss-datasource-jdbc.xml
export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
export jps_file="$DOMAIN_HOME/config/fmwconfig/jps-config.xml"
export jps_jse_file="$DOMAIN_HOME/config/fmwconfig/jps-config-jse.xml"
export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


if [ -f "${datasource_file}" ]; then
	echo "The datasource ${datasource_file} exists"
else
	echo "The datasource ${datasource_file} does not exist"
	echo "This is not a JRF/FMW domain. Exiting"
	exit
fi


gather_current_variables_from_DS() {
        echo "Getting variables from current datasource..."
	# Check dependencies
	if [[ ! -x "${exec_path}/fmw_get_ds_property.sh" ]]; then
              echo "Error!. The script ${exec_path}/fmw_get_ds_property.sh cannot be found or is not executable!"
	      echo "Make sure you have donwloaded the file to from"
	      echo "https://github.com/oracle-samples/maa/tree/main/app_dr_common, "
	      echo "placed it under ${exec_path} and that you have set execution rights on it."
              exit 1
	fi
	if [[ ! -x "${exec_path}/fmw_get_connect_string.sh " ]]; then
              echo "Error!. The script ${exec_path}/fmw_get_connect_string.sh cannot be found or is not executable!"
	      echo "Make sure you have donwloaded the file to from"
              echo "https://github.com/oracle-samples/maa/tree/main/app_dr_common, "
              echo "placed it under ${exec_path} and that you have set execution rights on it."
              exit 1
	fi
        export current_connect_string=$($exec_path/fmw_get_connect_string.sh $datasource_file)
        export current_jps_connect_string=$(grep url ${jps_file} | awk -F ':@' '{print $2}' |awk -F '"/>' '{print $1}')
	export tns_admin=$($exec_path/fmw_get_ds_property.sh $datasource_file 'oracle.net.tns_admin')
	echo ""
}

backup_folders() {
	echo "Taking backup of existing config/jdbc..."
	cp -rf ${DOMAIN_HOME}/config/jdbc   ${DOMAIN_HOME}/config/jdbc_bck${date_label}
	if [ -d "$DOMAIN_HOME/config/fmwconfig" ]; then
		echo "Taking backup of existing config/fmwconfig..."
		cp -rf ${DOMAIN_HOME}/config/fmwconfig   ${DOMAIN_HOME}/config/fmwconfig_bck${date_label}
	fi
	echo "Backup complete!"
	echo ""
}

deal_with_tns() {
	if [ -z "$tns_admin" ]; then
		echo "No tns_admin property was found in ${datasource_file}."
		echo "Adding it to datasource files..."
		export tns_admin_tmp=$HOME/tnsadmin_${date_label}
		export depname="EDG_DBdata_${date_label}"
		mkdir -p $tns_admin_tmp
		echo "Creating alias based on current jdbc url..."
                echo "$tns_alias = $current_connect_string" >> $tns_admin_tmp/tnsnames.ora
                echo "tns_admin for deployment added and tns alias created"
		echo "Deploying DBClientData Module..."
		cat <<EOF >>/tmp/update_${date_label}.py
connect('$DOMAINUSER','$DOMAINPASS','t3s://$ADMINVHN:$ADMINPORT')
edit()
startEdit()
deploy('$depname','$tns_admin_tmp', upload='true', dbClientData='true');
activate()
exit()
EOF
		export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=$TRUSTSTOREFILE -Dweblogic.security.CustomTrustKeyStorePassPhrase=$KEYPASS"
		$MW_HOME/oracle_common/common/bin/wlst.sh /tmp/update_${date_label}.py
		export tns_admin="${DOMAIN_HOME}/config/dbclientdata/$depname/"
		echo "DBClientData deployed!"
		rm -rf /tmp/update_${date_label}.py
		echo "Replacing connection strings in all datasources in the domain and FMW JPS configuration with TNS alias..."
		cd ${DOMAIN_HOME}/config/jdbc
		find . -name '*.xml' | xargs sed -i 's|</properties>|<property><name>oracle.net.tns_admin</name><value>'${tns_admin}'</value></property></properties>|gI'
		if [ -d "$DOMAIN_HOME/config/fmwconfig" ]; then
			echo "Adding it to jps-config.xml and jps-config-jse.xml files..."
			export add_str_jps_tns="<property name=\"oracle.net.tns_admin\" value=\"${tns_admin}\"/>"
			export line_number=$(awk '/jdbc.url/ { print NR; exit }' $jps_file)
			sed -i.bkp "$line_number i$add_str_jps_tns" $jps_file 
			export line_number=$(awk '/jdbc.url/ { print NR; exit }' $jps_jse_file)
			sed -i.bkp "$line_number i$add_str_jps_tns" $jps_jse_file
		fi
	else
		echo "An existing tns_admin property was found in $datasource_file !"
	       	echo "Modifications will not be performed to avoid conflicts"
		exit 1
	fi
}

replace_connect_info(){
	echo "Replacing DB connect information"
	echo "Replacing jdbc url in config/jdbc files..."
	cd ${DOMAIN_HOME}/config/jdbc
	find . -name '*.xml' | xargs sed -i 's|'"${current_connect_string}"'|'"${tns_alias}"'|gI'
	if [ -d "$DOMAIN_HOME/config/fmwconfig" ]; then
		echo "Replacing jdbc url in config/fmwconfig files..."
		cd ${DOMAIN_HOME}/config/fmwconfig
		export escaped_current_jps_connect_string=$(printf '%s\n' "$current_jps_connect_string" | sed -e 's/[\/&]/\\&/g')
		find . -name '*.xml' | xargs sed -i 's|'"${escaped_current_jps_connect_string}"'|'"${tns_alias}"'|gI'
	fi
	echo "Replacement complete!"
	echo ""
}

gather_current_variables_from_DS
echo "CONFIGURATION GATHERED:"
echo ""
echo "-TNS alias:........................ $tns_alias"
echo "-Current connect string:............$current_connect_string"
echo "-Current jps connect string:........$current_jps_connect_string"
echo ""

backup_folders
deal_with_tns
replace_connect_info

echo "***********************************************************************"
echo "DONE!"
echo "IMPORTANT: A RESTART OF THE WEBLOGIC ADMINISTRATION SERVER AND ALL MANAGED "
echo "SERVERS IS REQUIRED FOR CHANGES TO BE EFFECTIVE!"
echo "***********************************************************************"

echo "A copy of the previous jdbc and fmwconfig folders exist at:"
echo "  - ${DOMAIN_HOME}/config/fmwconfig_bck${date_label}"
echo "  - ${DOMAIN_HOME}/config/jdbc_bck${date_label}"
