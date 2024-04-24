#!/bin/bash

## generate_perdomainCACERTS-ohs.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates the required "WLS domain CA" certificates for the SSl virtual hosts used by OHS servers.
### This script should be executed in the WLS Admin Server node and in the directory that hosts the Trust and 
### Identity Stores used by the WLS domain.
### It is expected that the stores have already been create for the WLS domain (using enerate_perdomainCACERTS.sh)
### This will guarantee that the per domain CA is already in the TrustStore
### By doing so it keeps all EDG pertaining certificates in a single store (on shared storage in the App Tier and
### in private folders in each one of the OHS nodes).
### It uses an existing FMW/WLS installation (uses this for setting JAVA_HOME, WL_HOME etc). 
### It cannot be run in the OHS nodes becuase they lack the CerGen librariws.
### It will use the WLS domain config frontend addresses to add the required SANs to the certificates
### Usage:
###
###      	./generate_perdomainCACERTS-ohs.sh [WLS_DOMAIN_DIRECTORY] [MW_HOME] [KEYSTORE_HOME] [KEYPASS] [LIST_OF_OHS_SSL_VIRTUAL_HOSTS] 
### Where:
###		WLS_DOMAIN_DIRECTORY:
###			Directory hosting the Weblogic Domain that the Administration Server uses.
###		MW_HOME:
###			Location of the FMW/WLS installation.
###		KEYSTORE_HOME:
###			Directory where appIdentity and appTrust stores will be updated.
###		KEYPASS:
###			Password used for the weblogic administration user (will be reused for certs and stores)
###		LIST_OF_OHS_SSL_VIRTUAL_HOSTS:
###			A space seprated  list of OHS Virtual host addresses enclosed in single quotes '.

if [[ $# -eq 5 ]];
then
	export ASERVER=$1
	export MW_HOME=$2
	export KEYSTORE_HOME=$3
	export KEYPASS=$4
	export LIST_OF_OHS_SSL_VIRTUAL_HOSTS=$5
	
else
	echo ""
    	echo "ERROR: Incorrect number of parameters used: Expected 5, got $#"
	echo "Provide a list of virtual hosts inside single quotes and a store password"
    	echo ""
    	echo "Usage:"
    	echo "    $0 [WLS_DOMAIN_DIRECTORY] [MW_HOME] [KEYSTORE_HOME] [KEYPASS]"
    	echo ""
    	echo "Example:  "
    	echo "    $0 /u01/oracle/config/domains/soaedg /u01/oracle/products/fmw /u01/oracle/config/keystores mycertkeystorepass123 'ohstvhost1.soaedgexample.com ohstvhost2.soaedgexample.com'"
    	exit 1
fi
export dt=`date +%y-%m-%d-%H-%M-%S`
. $WL_HOME/server/bin/setWLSEnv.sh

#If the script is used 
mkdir -p $KEYSTORE_HOME
cd $KEYSTORE_HOME

#Preserve previous stores 
cp $KEYSTORE_HOME/appTrustKeyStore.jks $KEYSTORE_HOME/appTrustKeyStore.$dt.jks
cp $KEYSTORE_HOME/appIdentityKeyStore.jks $KEYSTORE_HOME/appIdentityKeyStore.$dt.jks

sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml

export list_of_fe=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-host"  | tr -d '[:space:]' | sed -e 's/<\/frontend-host>/\n/g' | awk -F'<frontend-host>' '{print $2}' |   awk '!x[$0]++')
export list_of_fe="${list_of_fe//$'\n'/ }"
export list_of_ports=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-https-port"  | tr -d '[:space:]' | sed -e 's/<\/frontend-https-port>/\n/g' | awk -F'<frontend-https-port>' '{print $2}' |   awk '!x[$0]++')
export list_of_ports="${list_of_ports//$'\n'/ }"

#Need to implement verification of matching number of ports and front ends. We will require
#that every FE uses and https port for this EDG

echo "List of front-ends : $list_of_fe"
echo "List of ports : $list_of_ports"
num_of_fe=$(echo $list_of_fe | awk '{print NF}')
declare -A matrix
for ((j=1;j<=num_of_fe;j++)) do
	matrix[$j,1]=$(echo $list_of_fe | awk -v count=$j '{print $count}')
	matrix[$j,2]=$(echo $list_of_ports | awk -v count=$j '{print $count}')
	matrix[$j,3]=$(echo ${matrix[$j,1]}:${matrix[$j,2]})
	sanurl+="DNS:${matrix[$j,1]},"
	echo "Downloading and adding front end cert for ${matrix[$j,3]}"
	openssl s_client -connect ${matrix[$j,3]} -showcerts </dev/null 2>/dev/null|openssl x509 -outform PEM > $KEYSTORE_HOME/${matrix[$j,3]}.crt
	keytool -import -file $KEYSTORE_HOME/${matrix[$j,3]}.crt -v -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -alias ${matrix[$j,1]} -storepass $KEYPASS

done

final_sanurl=$(echo $sanurl |sed -e 's/\(,\)*$//g')
echo "FINAL DNS string : $final_sanurl "

for vhost in ${LIST_OF_OHS_SSL_VIRTUAL_HOSTS}; do
	echo "Generating OHS Virtual Host certificate for $vhost..."
	java utils.CertGen -cn $vhost -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $KEYPASS -certfile $vhost.cert -keyfile $vhost.key -domain $ASERVER -nosanhostdns -a $final_sanurl
	echo "Cleaning previous alias and importing certificates in the Identity store..."
	keytool -delete -alias $vhost -storepass  $KEYPASS -keystore appIdentityKeyStore.jks
	java  utils.ImportPrivateKey -certfile $ASERVER/security/$vhost.cert.der -keyfile $ASERVER/security/$vhost.key.der -keyfilepass $KEYPASS -keystore appIdentityKeyStore.jks -storepass $KEYPASS -alias $vhost -keypass $KEYPASS
done

rm -rf /tmp/config-nons.xml
