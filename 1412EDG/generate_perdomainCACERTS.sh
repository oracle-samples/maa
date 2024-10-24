#!/bin/bash

## generate_perdomainCACERTS.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates the required per domain CA certificates for the listen addresses used in an existing WLS domain.
### -It adds the generated certificates to an identity store file (appIdentityKeyStore.$storetype) inside the KEYSTORE_HOME directory provided.
### -It creates a trust store file (appTrustKeyStore.$storetype) based on WL_HOME/server/lib/cacerts inside the KEYSTORE_HOME directory provided.
### -It needs an existing Oracle WebLogic installation (required for setting JAVA_HOME, WL_HOME etc) and an existing WLS domain.
### Usage:
###
###      	./generate_perdomainCACERTS.sh [WLS_DOMAIN_DIRECTORY] [WL_HOME] [KEYSTORE_HOME] [KEYPASS]
### Where:
###		WLS_DOMAIN_DIRECTORY:
###			Directory hosting the Weblogic Domain that the Administration Server uses.
###		WL_HOME:
###			The directory within the Oracle home where the Oracle WebLogic Server software binaries are stored.
### 			Typically /u01/oracle/products/fmw/wlserver
###		KEYSTORE_HOME:
###			Directory where appIdentity and appTrust stores will be created.
###		KEYPASS:
###			Password used for the weblogic administration user (will be reused for certs and stores).
### It can also be used to create and add a certs to an existing Identity Store for just a precise address use this syntax:"
### 		./generate_perdomainCACERTS.sh [WLS_DOMAIN_DIRECTORY] [WL_HOME] [KEYSTORE_HOME] [KEYPASS] [NEWADDR]
### Where
###		NEWADDR:
###			Address to be used in the new cert to be created and added to the Identity Store.
###

export storetype=pkcs12

createcertandadd (){
        hosty=$1
        if [ -f $KEYSTORE_HOME/appIdentityKeyStore.$storetype ]; then
                echo "Checking if an entry for the host $hosty already exists..."
		if [ $(keytool -list -keystore  $KEYSTORE_HOME/appIdentityKeyStore.$storetype -storepass $KEYPASS |  grep $hosty | grep -c PrivateKeyEntry) -ge 1 ]
        	then
                while true; do
                	read -p "An entry for host $hosty already exists in the Identity Store. Do you want to replace it? " yn
                        case $yn in
                        [Yy]* ) echo "Removing current entry for  $hosty"; addcert=true;keytool  -keystore $KEYSTORE_HOME/appIdentityKeyStore.$storetype  -storepass $KEYPASS  -delete  -noprompt -alias $hosty;break;;
                        [Nn]* ) echo "Skipping update for  $hosty";addcert=false;break ;;
                        * ) echo "Please answer y or n.";;
                        esac
                done

        	else
                addcert=true
        	fi
        else
                echo "Creating identity store by importing the cert for $hosty"
		addcert=true
        fi
	if [ "$addcert" = true ];then
        	echo "Generating and adding cert for $hosty"
        	java utils.CertGen -cn $hosty -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $KEYPASS -certfile $hosty.cert -keyfile $hosty.key -domain $ASERVER -nosanhostdns -validuntil "2030-03-01" >> $KEYSTORE_HOME/$hosty.CertGen.$dt.log 2>&1
                echo "Created a backup of previous IdentityStore at $KEYSTORE_HOME/appIdentityKeyStore.$hosty.$dt.$storetype"
                java  utils.ImportPrivateKey -certfile $ASERVER/security/$hosty.cert.der -keyfile $ASERVER/security/$hosty.key.der -keyfilepass $KEYPASS -keystore $KEYSTORE_HOME/appIdentityKeyStore.$storetype -storepass $KEYPASS -alias $hosty -keypass $KEYPASS -storetype $storetype  >> $KEYSTORE_HOME/$hosty.ImportPrivateKey.$dt.log 2>&1
	fi

}

if [[ $# -eq 4 ]];
then
	export ASERVER=$1
	export WL_HOME=$2
	export KEYSTORE_HOME=$3
	export KEYPASS=$4
	global="true"	
elif [[ $# -eq 5 ]];
then
	export ASERVER=$1
        export WL_HOME=$2
        export KEYSTORE_HOME=$3
        export KEYPASS=$4
	export NEWADDR=$5
        global="false"
else
    	echo ""
    	echo "ERROR: Incorrect number of parameters used: Expected 4 or 5, got $#"
    	echo ""
    	echo "Usage:"
	echo ""
	echo "-To generate a trust store with the per-domain CA and add certs for all listen addresses in a domain's config.xml"
	echo "use this syntax:"
    	echo "    $0 [WLS_DOMAIN_DIRECTORY] [WL_HOME] [KEYSTORE_HOME] [KEYPASS]"
	echo ""
    	echo "-To add the certs to an existing Identity Store for just a precise address use this syntax:"
        echo "    $0 [WLS_DOMAIN_DIRECTORY] [WL_HOME] [KEYSTORE_HOME] [KEYPASS] [NEWADDR]"
	echo ""
    	echo "Examples:  "
    	echo "    $0 /u01/oracle/config/domains/soaedg /u01/oracle/products/fmw/wlserver /u01/oracle/config/keystores mycertkeystorepass123"
	echo ""
	echo "    $0 /u01/oracle/config/domains/soaedg /u01/oracle/products/fmw/wlserver /u01/oracle/config/keystores mycertkeystorepass123 SOAHOST3"
    	exit 1
fi

export dt=`date +%y-%m-%d-%H-%M-%S`
. $WL_HOME/server/bin/setWLSEnv.sh

mkdir -p $KEYSTORE_HOME
cd $KEYSTORE_HOME

#Preserve previous stores in case they had been created out of this script or in previous domain ops. 
#If trust does not exist we create it from $WL_HOME/server/lib/cacerts.
#If identity does not exists, we will create it with first import.

if [ -f $KEYSTORE_HOME/appTrustKeyStore.$storetype ]; then
	echo "Trust store exists. Creating a backup..."
	cp $KEYSTORE_HOME/appTrustKeyStore.$storetype $KEYSTORE_HOME/appTrustKeyStore.$dt.$storetype
else
	echo "Trust store does not exist, creating it from domain ca import..."
        keytool -import -v -noprompt -trustcacerts -alias domainCA -file $ASERVER/security/democacert.der -keystore $KEYSTORE_HOME/appTrustKeyStore.$storetype -storepass $KEYPASS -storetype  $storetype >> $KEYSTORE_HOME/appTrustKeyStore.domainCA.$dt.log 2>&1
fi
if [ -f $KEYSTORE_HOME/appIdentityKeyStore.$storetype ]; then
	echo "Identity store exists. Creating a backup..."
	cp $KEYSTORE_HOME/appIdentityKeyStore.$storetype $KEYSTORE_HOME/appIdentityKeyStore.$dt.$storetype
else
	 echo "Identity store does not exists, will create it with first imported cert."
fi

if [ $global == "true" ];then
	echo ""
	echo "***************************************************************************"
	echo "*** CREATING AND IMPORTING CERTS FOR THE LISTEN ADDRESSES IN THE DOMAIN ***"
	echo "***************************************************************************"
	echo ""

	cd $KEYSTORE_HOME
	#Logic to overcome limitations of Xpath 1.0
	sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml
	list_of_hosts=$(xmllint /tmp/config-nons.xml --xpath  "//listen-address"  | tr -d '[:space:]' | sed -e 's/<\/listen-address>/\n/g' | awk -F'<listen-address>' '{print $2}' |   awk '!x[$0]++' | awk '{print $1}')
	trimmed_list_of_hosts="${list_of_hosts//$'\n'/ }"
	echo "Creating and importing certs for: $trimmed_list_of_hosts"
	for hosty in $trimmed_list_of_hosts; do
		createcertandadd $hosty
	done
	rm -rf /tmp/config-nons.xml
else 
	echo "Creating and importing certs just for $NEWADDR"
	createcertandadd $NEWADDR
fi

echo ""
echo "Creation of certs and imports completed!"

