#!/bin/bash

## fmw_change_to_tns_alias.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# -This script can be used to replace the connect strings used by WLS datasources (under $DOMAIN_HOME}/config/jdbc)
# and jps config files (under ${DOMAIN_HOME}/config/fmwconfig) with a tns alias
# -Note this performs replacements in the WLS configuration files, so it must be used conscientiously and requires restart of the WLS servers to take effect
# -The script uses fmw_get_ds_property.sh and fmw_get_connect_string.sh so make sure to place them together with this script
# -Refer to the Oracle NET Services Adminsitration guide for allowed connect descriptor formats. For example, ezconnect short-string formats like 
# //db:port/service are not supported by multiple Oracle NET Local Naming versions) 

# The script gathers the current connect string from the opss-datasource-jdbc.xml (can be executed multiple times
# each with a different DS if different connect strings are used by other DS) and replaces them with the tnsalias  provided as parameter.
# If the tns alias exists already it is used. If not an appropriate entry is added in tnsnames.ora (which is created if does not exist before also)

### Usage:
###	./fmw_change_to_tns_alias.sh alias
###
### Where:
###	alias is the alias for the entry in tnsnames.ora
### EXAMPLE:
### ./fmw_change_to_tns_alias.sh soapdb


export date_label=$(date '+%d-%m-%Y-%H-%M-%S')
export datasource_name=opss-datasource-jdbc.xml
export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
export jps_file="$DOMAIN_HOME/config/fmwconfig/jps-config.xml"
export jps_jse_file="$DOMAIN_HOME/config/fmwconfig/jps-config-jse.xml"
export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $# -eq 1 ]]; then
	export tns_alias=$1
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 1, got $#"
	echo "Usage :"
	echo "    $0  ALIAS "
	echo "Example:  "
	echo "    $0  'soaadb1_low'"
	echo ""
	exit 1
fi

if [ -f "${datasource_file}" ]; then
	echo "The datasource ${datasource_file} exists"
else
	echo "The datasource ${datasource_file} does not exist"
	echo "Provide an alternative datasource name"
	exit
fi


gather_current_variables_from_DS() {
        echo "Getting variables from current datasource..."
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
		export tns_admin="$DOMAIN_HOME/config/tnsadmin"
		mkdir -p $tns_admin
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
		echo "Creating alias based on current jdbc url..."
		echo "$tns_alias = $current_connect_string" >> $tns_admin/tnsnames.ora
		echo "tns_admin added and tns alias created"
	else
		echo "An existing tns_admin property was found in $datasource_file and will be used"
		if [ -z "$(grep $tns_alias $tns_admin/tnsnames.ora | awk -F '=' '{print $1}')" ]; then
			echo "The provided alias does not exist in $tns_admin/tnsnames.ora"
			echo "Will add it to $tns_admin/tnsnames.ora"
			echo "$tns_alias = $current_connect_string" >> $tns_admin/tnsnames.ora
		else
			echo "Found $(grep $tns_alias ${tns_admin}/tnsnames.ora | awk -F '=' '{print $1}') as tns_alias"
			echo "No modifications will be required in $tns_admin/tnsnames.ora"
        fi
	fi
	
	echo ""
	echo "WILL USE THESE SETTINGS:"
	echo ""
	echo "TNS admin:.........................$tns_admin"
	echo "TNS alias:........................ $tns_alias"
	echo "Current connect string:............$current_connect_string"
	echo "Current jps connect string:........$current_jps_connect_string"
	echo "Current tnsnames.ora:.............."
	cat $tns_admin/tnsnames.ora
	echo ""
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

remove_ons_list(){
	cd ${DOMAIN_HOME}/config/jdbc
	echo "Removing ONS node list from datasources. Will use auto ONS feature..."
	find . -name '*.xml' | xargs sed -i '/ons-node-list/d' 
	cd ${exec_path}
	echo "Remove complete!"
	echo ""

}

gather_current_variables_from_DS
backup_folders
deal_with_tns
replace_connect_info
remove_ons_list
