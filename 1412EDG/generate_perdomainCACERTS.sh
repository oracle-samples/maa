#!/bin/bash

## generate_perdomainCACERTS.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates the required per domain CA certificates for the listen addresses used in an existing WLS domain.
### It needs an existing FMW/WLS installation (required for setting JAVA_HOME, WL_HOME etc).
### Usage:
###
###      	./generate_perdomainCACERTS.sh [WLS_DOMAIN_DIRECTORY] [MW_HOME] [KEYSTORE_HOME] [KEYPASS]
### Where:
###		WLS_DOMAIN_DIRECTORY:
###			Directory hosting the Weblogic Domain that the Administration Server uses.
###		MW_HOME:
###			Location of the FMW/WLS installation.
###		KEYSTORE_HOME:
###			Directory where appIdentity and appTrust stores will be created.
###		KEYPASS:
###			Password used for the weblogic administration user (will be reused for certs and stores).
if [[ $# -eq 4 ]];
then
	export ASERVER=$1
	export MW_HOME=$2
	export KEYSTORE_HOME=$3
	export KEYPASS=$4	
else
	echo ""
    echo "ERROR: Incorrect number of parameters used: Expected 4, got $#"
    echo ""
    echo "Usage:"
    echo "    $0 [WLS_DOMAIN_DIRECTORY] [MW_HOME] [KEYSTORE_HOME] [KEYPASS]"
    echo ""
    echo "Example:  "
    echo "    $0 /u01/oracle/config/domains/soaedg /u01/oracle/products/fmw /u01/oracle/config/keystores mycertkeystorepass123"
    exit 1
fi

export dt=`date +%y-%m-%d-%H-%M-%S`
. $MW_HOME/wlserver/server/bin/setWLSEnv.sh

mkdir -p $KEYSTORE_HOME
cd $KEYSTORE_HOME

#Preserve previous stores in case they had been created out of this script or in previous domain ops
if [ -f $KEYSTORE_HOME/appTrustKeyStore.jks ]; then
	cp $KEYSTORE_HOME/appTrustKeyStore.jks $KEYSTORE_HOME/appTrustKeyStore.$dt.jks
fi
if [ -f $KEYSTORE_HOME/appIdentityKeyStore.jks ]; then
	cp $KEYSTORE_HOME/appIdentityKeyStore.jks $KEYSTORE_HOME/appIdentityKeyStore.$dt.jks
fi

cp $MW_HOME/wlserver/server/lib/cacerts $KEYSTORE_HOME/appTrustKeyStore.jks

keytool -storepasswd -new $KEYPASS -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -storepass changeit
cd $KEYSTORE_HOME

#Import wls demo CA
keytool -import -v -noprompt -trustcacerts -alias clientCACert -file $WL_HOME/server/lib/CertGenCA.der -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -storepass $KEYPASS

#Import the domain CA cert
keytool -import -v -noprompt -trustcacerts -alias domainCA -file $ASERVER/security/democacert.der -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -storepass $KEYPASS

#Logic to overcome limitations of Xpath 1.0
sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml

list_of_hosts=$(xmllint /tmp/config-nons.xml --xpath  "//listen-address"  | tr -d '[:space:]' | sed -e 's/<\/listen-address>/\n/g' | awk -F'<listen-address>' '{print $2}' |   awk '!x[$0]++' | awk '{print $1}')

trimmed_list_of_hosts="${list_of_hosts//$'\n'/ }"

echo "Creating and importing certs for: $trimmed_list_of_hosts"

for hosty in $trimmed_list_of_hosts; do
        java utils.CertGen -cn $hosty -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $KEYPASS -certfile $hosty.cert -keyfile $hosty.key -domain $ASERVER -nosanhostdns
	echo "Cleaning alias if it exists already..."
        keytool -delete -alias $hosty -storepass  $KEYPASS -keystore appIdentityKeyStore.jks
        java  utils.ImportPrivateKey -certfile $ASERVER/security/$hosty.cert.der -keyfile $ASERVER/security/$hosty.key.der -keyfilepass $KEYPASS -keystore $KEYSTORE_HOME/appIdentityKeyStore.jks -storepass $KEYPASS -alias $hosty -keypass $KEYPASS
done
rm -rf /tmp/config-nons.xml
