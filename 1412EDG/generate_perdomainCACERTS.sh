#!/bin/bash

## generate_perdomainCACERTS.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates the required per domain CA certificates for the listen addresses used in the domain
### This script should be executed in directory that hosts the Trust and Identity Stores used by the domain
### It uses an existing FMW/WLS installation
### It expects the typical variables used by an Enteprise Deployment Guide to be set already: JAVA_HOME, 
### ASERVER (domain dirrctory), MW_HOME in the existing shell/user
### Usage:
###
###      	./generate_perdomainCACERTS.sh [KEYPASS]
### Where:
###		KEYPASS:
###			This is the password that will be used for keys and stores (same for all of them)

export keypass=$1

. $MW_HOME/wlserver/server/bin/setWLSEnv.sh

### These variable can be customized here if no set in the env
export ASERVER=/u01/oracle/config/domains/soast32edg
export KEYSTORE_HOME=/u01/oracle/config/keystores/
export MW_HOME=/u01/oracle/products/fmw/
export JAVA_HOME=/u01/oracle/products/jdk
export PATH=$JAVA_HOME/bin:$PATH

cp $MW_HOME/wlserver/server/lib/cacerts $KEYSTORE_HOME/appTrustKeyStore.jks
keytool -storepasswd -new $keypass -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -storepass changeit
cd $KEYSTORE_HOME

#Import wls demo CA
keytool -import -v -noprompt -trustcacerts -alias clientCACert -file $WL_HOME/server/lib/CertGenCA.der -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -storepass $keypass

#Import the domain CA cert
keytool -import -v -noprompt -trustcacerts -alias domainCA -file $ASERVER/security/democacert.der -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -storepass $keypass

sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml

list_of_hosts=$(xmllint /tmp/config-nons.xml --xpath  "//listen-address"  | tr -d '[:space:]' | sed -e 's/<\/listen-address>/\n/g' | awk -F'<listen-address>' '{print $2}' |   awk '!x[$0]++' | awk '{print $1}')

trimmed_list_of_hosts="${list_of_hosts//$'\n'/ }"

echo "Creating and importing certs for: $trimmed_list_of_hosts"

for hosty in $trimmed_list_of_hosts; do
        java utils.CertGen -cn $hosty -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $keypass -certfile $hosty.cert -keyfile $hosty.key -domain $ASERVER -selfsigned -nosanhostdns
        keytool -delete -alias $hosty -storepass  $keypass -keystore appIdentityKeyStore.jks
        java  utils.ImportPrivateKey -certfile $ASERVER/security/$hosty.cert.der -keyfile $ASERVER/security/$hosty.key.der -keyfilepass $keypass -keystore $KEYSTORE_HOME/appIdentityKeyStore.jks -storepass $keypass -alias $hosty -keypass $keypass
done
rm -rf /tmp/config-nons.xml