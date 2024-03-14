#!/bin/bash

## fmwadb_switch_db_conn.sh script version 2.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script can be executed in any WLS DOMAIN using ADB where the datasources are using tns alias.
### It replaces the existing connect information with a new ADB WALLET. The script checks the validity of the new wallet and password
### Notice that the change in datasources requires the WLS servers to be restarted to be effective
###
###      ./fmwadb_switch_db_conn.sh [WALLET_DIR] [WALLET_PASSWORD]
### Where:
###	WALLET_DIR:
###					This is the directory for an unzipped ADB wallet.
###					This directory should contain at least a tnsnames.ora, keystore.jks and truststore.jks files. 
###	WALLET_PASSWORD:		
###					This is the password provided when the wallet was downloaded from the ADB OCI UI.
###					If the wallet is the initial one created by WLS/SOA/FMW when provisioning with WLS, the password can be obtained with the
###					following command:  python /opt/scripts/atp_db_util.py generate-atp-wallet-password

export datasource_name=opss-datasource-jdbc.xml
export datasource_file="$DOMAIN_HOME/config/jdbc/$datasource_name"
export date_label=$(date +%H_%M_%S-%d-%m-%y)
export exec_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $# -eq 2 ]]; then
	export WALLET_DIR=$1
	export WALLET_PASSWORD=$2
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 2, got $#"
	echo "Usage :"
	echo "    $0  WALLET_DIR WALLET_PASSWORD"
	echo "Example:  "
	echo "    $0  '/tmp/atprc' 'my_pwdXXXX'"
	echo ""
	exit 1
fi

check_wallet(){
	export validation=$(keytool -storepass $WALLET_PASSWORD -v -list -keystore $WALLET_DIR/keystore.jks  2>/dev/null) 
	if echo "$validation" | grep -q "Your keystore contains"; then
		echo "The password provided for the wallet is valid. Proceeding..."
	else
		echo "The password provided for the wallet's store is invalid"
                echo "Check you password and/or wallet!!"
                exit
	fi
}
gather_ds_info() {
	echo "Gathering Data Soure information..."
	export old_wallet_password_enc=$(${exec_path}/fmw_get_ds_property.sh $datasource_file 'javax.net.ssl.keyStorePassword')
	# cleanup commented lines before release (was tmp fix for SOAMP )
	#if [[ $old_wallet_password_enc != *"AES"* ]]; then
		# not encrypted
	#	export old_wallet_password=$old_wallet_password_enc
	#else
		#  encrypted
	export old_wallet_password=$(${exec_path}/fmw_dec_pwd.sh ${old_wallet_password_enc})
	#fi
	# end tmp fix
	export old_tns_amin=$(${exec_path}/fmw_get_ds_property.sh $datasource_file 'oracle.net.tns_admin')
}

create_config_backup() {
	#Imprtant: we only backup DS
    echo "Backing up the current datasource configuration..."
	mkdir -p  ${DOMAIN_HOME}/config/DS_backup_$date_label
    cp -R ${DOMAIN_HOME}/config/jdbc ${DOMAIN_HOME}/config/DS_backup_$date_label/
	cp -R ${DOMAIN_HOME}/config/fmwconfig ${DOMAIN_HOME}/config/DS_backup_$date_label/
    echo "Datasource backup created at  ${DOMAIN_HOME}/DS_backup_$date_label"

}


replace_connect_info() {
	new_wallet_password_enc=$(${exec_path}/fmw_enc_pwd.sh ${WALLET_PASSWORD})
	echo "Replacing values in datasources..."
    cd ${DOMAIN_HOME}/config/jdbc
	# cleanup commented lines before release (was tmp fix for SOAMP )
	# if [[ $old_wallet_password_enc != *"AES"* ]]; then
    #  	find . -name '*.xml' | xargs sed -i 's|'"${old_wallet_password}"'|'"${WALLET_PASSWORD}"'|gI'
	#else
		#In datasources the password are now encrypted
	find . -name '*.xml' | xargs sed -i '/javax.net.ssl.trustStorePassword/{n;s|'"<encrypted-value-encrypted>.*</encrypted-value-encrypted>"'|'"<encrypted-value-encrypted>${new_wallet_password_enc}</encrypted-value-encrypted>"'|}'
    find . -name '*.xml' | xargs sed -i '/javax.net.ssl.keyStorePassword/{n;s|'"<encrypted-value-encrypted>.*</encrypted-value-encrypted>"'|'"<encrypted-value-encrypted>${new_wallet_password_enc}</encrypted-value-encrypted>"'|}'
	#fi
    cd ${DOMAIN_HOME}/config/fmwconfig
    find . -name '*.xml' | xargs sed -i 's|'"${old_wallet_password}"'|'"${WALLET_PASSWORD}"'|gI'
    echo "Replacement complete!"

}

manage_wallet() {
	mv ${old_tns_amin} ${old_tns_amin}-${date_label}
	cp -r $WALLET_DIR $old_tns_amin
}

check_wallet
gather_ds_info
export differ=$(diff ${old_tns_amin} $WALLET_DIR)
if [ "$differ" != "" ];then
	echo "Updating with new wallet"
	create_config_backup
	replace_connect_info
	manage_wallet
else
	echo "The new wallet is the same as the one being used."
	echo "Will maintain existing wallet dir and just replace password"
	create_config_backup
	replace_connect_info

fi


