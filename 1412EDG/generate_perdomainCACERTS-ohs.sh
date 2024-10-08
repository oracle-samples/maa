#!/bin/bash

## generate_perdomainCACERTS-ohs.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates the required "WLS domain CA" certificates for the SSl virtual hosts used by OHS servers.
### It also downloads and adds certiicates for the different front-end addresses found in the WLS config.xml file.
### This is done to allow loopbacks and invocations from WLS servers to frontend addresses when these front end addresses are using SSL
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
###      	./generate_perdomainCACERTS-ohs.sh [WLS_DOMAIN_DIRECTORY] [WL_HOME] [KEYSTORE_HOME] [KEYPASS] [LIST_OF_OHS_SSL_VIRTUAL_HOSTS] 
### Where:
###		WLS_DOMAIN_DIRECTORY:
###			Directory hosting the Weblogic Domain that the Administration Server uses.
###		WL_HOME:
###			The directory within the Oracle home where the Oracle WebLogic Server software binaries are stored.
### 			Typically /u01/oracle/products/fmw/wlserver
###		KEYSTORE_HOME:
###			Directory where appIdentity and appTrust stores will be updated.
###		KEYPASS:
###			Password used for the weblogic administration user (will be reused for certs and stores)
###		LIST_OF_OHS_SSL_VIRTUAL_HOSTS:
###			A space seprated  list of OHS Virtual host addresses enclosed in single quotes '.

if [[ $# -eq 5 ]];
then
	export ASERVER=$1
	export WL_HOME=$2
	export KEYSTORE_HOME=$3
	export KEYPASS=$4
	export LIST_OF_OHS_SSL_VIRTUAL_HOSTS=$5
	
else
	echo ""
    	echo "ERROR: Incorrect number of parameters used: Expected 5, got $#"
	echo "Provide a list of virtual hosts inside single quotes and a store password"
    	echo ""
    	echo "Usage:"
    	echo "    $0 [WLS_DOMAIN_DIRECTORY] [WL_HOME] [KEYSTORE_HOME] [KEYPASS] [LIST_OF_OHS_SSL_VIRTUAL_HOSTS]"
    	echo ""
    	echo "Example:  "
    	echo "    $0 /u01/oracle/config/domains/soaedg /u01/oracle/products/fmw/wlserver /u01/oracle/config/keystores mycertkeystorepass123 'ohstvhost1.soaedgexample.com:4445 ohstvhost2.soaedgexample.com:4445'"
    	exit 1
fi
export dt=`date +%y-%m-%d-%H-%M-%S`
. $WL_HOME/server/bin/setWLSEnv.sh

#If the script is used 
mkdir -p $KEYSTORE_HOME
cd $KEYSTORE_HOME

#Preserve previous stores in case they had been created out of this script or in previous domain ops
if [ -f $KEYSTORE_HOME/appTrustKeyStore.jks ]; then
	cp $KEYSTORE_HOME/appTrustKeyStore.jks $KEYSTORE_HOME/appTrustKeyStore.$dt.jks
fi
if [ -f $KEYSTORE_HOME/appIdentityKeyStore.jks ]; then
	cp $KEYSTORE_HOME/appIdentityKeyStore.jks $KEYSTORE_HOME/appIdentityKeyStore.$dt.jks
fi

sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml

export list_of_fe=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-host"  | tr -d '[:space:]' | sed -e 's/<\/frontend-host>/\n/g' | awk -F'<frontend-host>' '{print $2}')
export list_of_fe="${list_of_fe//$'\n'/ }"
export list_of_ports=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-https-port"  | tr -d '[:space:]' | sed -e 's/<\/frontend-https-port>/\n/g' | awk -F'<frontend-https-port>' '{print $2}')
export list_of_ports="${list_of_ports//$'\n'/ }"

#Always assuming there is an appropriate config.xml with always a frontend port for every frontend host
echo "***************************************************************************"
echo "****** ADDING THE FRONT-END ADDRESSES CERTIFICATES TO THE TRUST STORE******"
echo "***************************************************************************"

echo "List of front-ends : $list_of_fe"
echo "List of ports : $list_of_ports"
num_of_fe=$(echo $list_of_fe | awk '{print NF}')
declare -A matrix

for ((j=1;j<=num_of_fe;j++)) do
	matrix[$j,1]=$(echo $list_of_fe | awk -v count=$j '{print $count}')
	matrix[$j,2]=$(echo $list_of_ports | awk -v count=$j '{print $count}')
	matrix[$j,3]=$(echo ${matrix[$j,1]}:${matrix[$j,2]})
	sanurl+="DNS:${matrix[$j,1]},"
	if [ $(keytool -list -keystore $KEYSTORE_HOME/appTrustKeyStore.jks  -storepass $KEYPASS |  grep ${matrix[$j,3]} | grep -c trustedCertEntry) -ge 1 ]
	then
		while true; do
			read -p "An alias for for frontend ${matrix[$j,3]} already exists in the truststore. Do you want to replace it? " yn
			case $yn in
        			[Yy]* ) echo "Removing current cert for ${matrix[$j,3]}"; addtrust=true;keytool  -keystore $KEYSTORE_HOME/appTrustKeyStore.jks  -storepass $KEYPASS  -delete  -noprompt -alias ${matrix[$j,3]};break;;
        			[Nn]* ) echo "Skipping download and update for ${matrix[$j,3]}";addtrust=false;break ;;
        			* ) echo "Please answer y or n.";;
    			esac
		done
	else
		 addtrust=true
	fi
	if [ "$addtrust" = true ];then
		echo "Downloading and adding front end cert for ${matrix[$j,3]}"
		openssl s_client -connect ${matrix[$j,3]} -showcerts </dev/null 2>/dev/null|openssl x509 -outform PEM > $KEYSTORE_HOME/${matrix[$j,3]}.crt
		keytool -import -file $KEYSTORE_HOME/${matrix[$j,3]}.crt -v -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -alias ${matrix[$j,3]} -storepass $KEYPASS
	fi
done

final_sanurl=$(echo $sanurl |sed -e 's/\(,\)*$//g')

echo "***************************************************************************"
echo "******* CREATING AND ADDING CERTIFICATES FOR THE OHS VIRTUAL HOSTS  *******"
echo "***************************************************************************"

#We qualify alias with port in case we have mutiple certs for different virtuaL host that
#share the same host but listen on different port
echo ""
for vhost in ${LIST_OF_OHS_SSL_VIRTUAL_HOSTS}; do
	 #Check if the cert for this virtual host already exists
	if [ $(keytool -list -keystore  appIdentityKeyStore.jks -storepass $KEYPASS |  grep $vhost | grep -c PrivateKeyEntry) -ge 1 ]
	then
		while true; do
                       	read -p "An entry for virtual host $vhost already exists in the Identity Store. Do you want to replace it? " yn
	        	case $yn in
        		[Yy]* ) echo "Removing current entry for  $vhost"; addcert=true;keytool  -keystore $KEYSTORE_HOME/appIdentityKeyStore.jks  -storepass $KEYPASS  -delete  -noprompt -alias $vhost;break;;
                	[Nn]* ) echo "Skipping update for  $vhost";addcert=false;break ;;
                	* ) echo "Please answer y or n.";;
                        esac
		done

	else
     addcert=true
   fi
   if [ "$addcert" = true ];then
		echo ""
		echo "Generating and adding cert for $vhost"
        	java utils.CertGen -cn $vhost -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $KEYPASS -certfile $vhost.cert -keyfile $vhost.key -domain $ASERVER -nosanhostdns -a $final_sanurl -validuntil "2030-03-01"
        	java  utils.ImportPrivateKey -certfile $ASERVER/security/$vhost.cert.der -keyfile $ASERVER/security/$vhost.key.der -keyfilepass $KEYPASS -keystore $KEYSTORE_HOME/appIdentityKeyStore.jks -storepass $KEYPASS -alias $vhost -keypass $KEYPASS
		echo ""
		echo "Updating orapki wallet with new cert..."
                if [ -f $KEYSTORE_HOME/orapki ]; then
                        echo "Root orapki wallet already exists, adding just the new cert... "
                else
                        echo "Root orapki wallet does not exist, creating it and adding the new certs for WLS access..."
			mkdir -p  $KEYSTORE_HOME/orapki/
			$WL_HOME/../bin/orapki wallet create -wallet $KEYSTORE_HOME/orapki/ -auto_login_only
			$WL_HOME/../bin/orapki wallet jks_to_pkcs12 -wallet  $KEYSTORE_HOME/orapki/ -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -jkspwd $KEYPASS
                fi
		rm -rf $KEYSTORE_HOME/orapki/orapki-vh-$vhost
		mkdir -p $KEYSTORE_HOME/orapki/orapki-vh-$vhost
		echo ""
		$WL_HOME/../bin/orapki wallet create -wallet $KEYSTORE_HOME/orapki/orapki-vh-$vhost -auto_login_only
		$WL_HOME/../bin/orapki wallet jks_to_pkcs12 -wallet $KEYSTORE_HOME/orapki/orapki-vh-$vhost -keystore $KEYSTORE_HOME/appIdentityKeyStore.jks -jkspwd $KEYPASS -aliases $vhost
		$WL_HOME/../bin/orapki wallet jks_to_pkcs12 -wallet  $KEYSTORE_HOME/orapki/orapki-vh-$vhost -keystore $KEYSTORE_HOME/appTrustKeyStore.jks -jkspwd $KEYPASS
    fi
done
cd $KEYSTORE_HOME
tar -czvf  $KEYSTORE_HOME/orapki-ohs.gz ./orapki
echo "******************************************************"
echo "Tar to ship to ohs nodes: $KEYSTORE_HOME/orapki-ohs.gz"
echo "******************************************************"

rm -rf /tmp/config-nons.xml
