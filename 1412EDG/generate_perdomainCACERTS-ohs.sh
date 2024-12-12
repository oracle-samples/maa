#!/bin/bash

## generate_perdomainCACERTS-ohs.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script generates the required "WLS domain CA" certificates for the SSl virtual hosts used by OHS servers.
### - It will use the WLS domain config frontend addresses to add the required SANs to the OHS certificates.
### - It also downloads and adds CA certificates for the different front-end addresses found in the WLS config.xml file.
### This is done to allow loopbacks and invocations from WLS servers to frontend addresses when these front end addresses are using SSL
### - This script should be executed in the WLS Administration Server node and in the directory that hosts the Trust and 
### Identity Stores used by the WLS domain.
### - It is expected that the Identity and Trust stores have already been create for the WLS domain (using generate_perdomainCACERTS.sh)
### This will guarantee that the per domain CA is already in the TrustStore. By doing so it keeps all Enterprise Deployment 
### Guide's pertaining certificates in a single store (on shared storage in the App Tier and
### in private folders in each one of the OHS nodes).
### - It uses an existing FMW/WLS installation (required for setting JAVA_HOME, WL_HOME etc). 
### - It cannot be run in the OHS nodes becuase they lack the required CerGen libraries.
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
###			Password used for the weblogic administration user (which is reused for certs and stores)
###		LIST_OF_OHS_SSL_VIRTUAL_HOSTS:
###			A space separated list of OHS Virtual host addresses enclosed in single quotes ' (just the host address, do not include the port).

## Only jks and pkcs12 are admited as store formats.
export storetype=pkcs12

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
    	echo "    $0 /u01/oracle/config/domains/soaedg /u01/oracle/products/fmw/wlserver /u01/oracle/config/keystores mycertkeystorepass123 'ohstvhost1.soaedgexample.com ohstvhost2.soaedgexample.com'"
    	exit 1
fi
export dt=`date +%y-%m-%d-%H-%M-%S`
. $WL_HOME/server/bin/setWLSEnv.sh

if [ -f $KEYSTORE_HOME/appTrustKeyStore.$storetype ]; then
	cp $KEYSTORE_HOME/appTrustKeyStore.$storetype $KEYSTORE_HOME/appTrustKeyStore.$dt.$storetype
else
	echo""
	echo "appTrustKeyStore.$storetype not found under $KEYSTORE_HOME." 
	echo "Make sure you have used generate_perdomainCACERTS.sh before running this script!"
	exit
fi
if [ -f $KEYSTORE_HOME/appIdentityKeyStore.$storetype ]; then
	cp $KEYSTORE_HOME/appIdentityKeyStore.$storetype $KEYSTORE_HOME/appIdentityKeyStore.$dt.$storetype
else
	echo""
	echo "appIdentityKeyStore.$storetype not found under $KEYSTORE_HOME."
        echo"Make sure you have used generate_perdomainCACERTS.sh before running this script!"
        exit
fi

sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml

export list_of_fe=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-host"  | tr -d '[:space:]' | sed -e 's/<\/frontend-host>/\n/g' | awk -F'<frontend-host>' '{print $2}')
export list_of_fe="${list_of_fe//$'\n'/ }"
export list_of_ports=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-https-port"  | tr -d '[:space:]' | sed -e 's/<\/frontend-https-port>/\n/g' | awk -F'<frontend-https-port>' '{print $2}')
export list_of_ports="${list_of_ports//$'\n'/ }"

echo "***************************************************************************"
echo "**** ADDING THE FRONT-END ADDRESSES' CA/CERTIFICATES TO THE TRUST STORE ***"
echo "***************************************************************************"

num_of_fe=$(echo $list_of_fe | awk '{print NF}')
if [[ $num_of_fe -lt 1 ]]; then
	echo "No front ends have been set in the WLS domain!"
	echo "At least one front end is required to add the certificate's SANs."
	echo "Exiting..."
	exit
fi
declare -A matrix

for ((j=1;j<=num_of_fe;j++)) do
	matrix[$j,1]=$(echo $list_of_fe | awk -v count=$j '{print $count}')
	matrix[$j,2]=$(echo $list_of_ports | awk -v count=$j '{print $count}')
	matrix[$j,3]=$(echo ${matrix[$j,1]}:${matrix[$j,2]})
	sanurl+="DNS:${matrix[$j,1]},"
	echo ""
	echo "Downloading and adding cert and chain for ${matrix[$j,3]}"
        mkdir -p $KEYSTORE_HOME/${matrix[$j,3]}

        openssl s_client -connect ${matrix[$j,3]} -showcerts </dev/null 2>/dev/null| sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'  > $KEYSTORE_HOME/${matrix[$j,3]}.crt
        cd $KEYSTORE_HOME/${matrix[$j,3]}
        awk 'BEGIN {c=0;} /BEGIN CERT/{c++} { print > "certchain." c ".pem"}' < $KEYSTORE_HOME/${matrix[$j,3]}.crt
        for pemfilewithpath in $KEYSTORE_HOME/${matrix[$j,3]}/certchain.*.pem
	do
		pemfile=$(basename -- "$pemfilewithpath")
		if [ $(keytool -list -keystore $KEYSTORE_HOME/appTrustKeyStore.$storetype  -storepass $KEYPASS |  grep -w ${matrix[$j,3]}.$pemfile| grep -c trustedCertEntry) -ge 1 ]
	       	then
			echo ""
			while true; do
				read -p "An alias for for ${matrix[$j,3]}.$pemfile already exists in the truststore. Do you want to replace it? " yn
                		case $yn in
                                [Yy]* ) echo "Removing current cert for ${matrix[$j,3]}.$pemfile"; addtrust=true;keytool  -keystore $KEYSTORE_HOME/appTrustKeyStore.$storetype  -storepass $KEYPASS  -delete  -noprompt -alias ${matrix[$j,3]}.$pemfile;break;;
                                [Nn]* ) echo "Skipping update for ${matrix[$j,3]}.$pemfile";addtrust=false;break ;;
                                * ) echo "Please answer y or n.";;
                        	esac
                	done
		else
                	addtrust=true
        	fi
		if [ "$addtrust" = true ];then
			echo "Adding cert chain for ${matrix[$j,3]}.$pemfile"
			keytool -import -file $pemfile -trustcacerts -keystore $KEYSTORE_HOME/appTrustKeyStore.$storetype -alias ${matrix[$j,3]}.$pemfile -storepass $KEYPASS -storetype $storetype
		fi		
	done
done

final_sanurl=$(echo $sanurl |sed -e 's/\(,\)*$//g')


echo ""
echo "***************************************************************************"
echo "******* CREATING AND ADDING CERTIFICATES FOR THE OHS VIRTUAL HOSTS  *******"
echo "***************************************************************************"
echo ""
for vhost in ${LIST_OF_OHS_SSL_VIRTUAL_HOSTS}; do
	#Check if the cert for this virtual host already exists
	mkdir -p $KEYSTORE_HOME/$vhost
	if [ $(keytool -list -keystore $KEYSTORE_HOME/appIdentityKeyStore.$storetype -storepass $KEYPASS |  grep $vhost | grep -c PrivateKeyEntry) -ge 1 ]
	then
		while true; do
                       	read -p "An entry for virtual host $vhost already exists in the Identity Store. Do you want to replace it? " yn
	        	case $yn in
        		[Yy]* ) echo "Removing current entry for  $vhost..."; addcert=true;keytool  -keystore $KEYSTORE_HOME/appIdentityKeyStore.$storetype  -storepass $KEYPASS  -delete  -noprompt -alias $vhost;break;;
                	[Nn]* ) echo "Skipping update for  $vhost...";addcert=false;break ;;
                	* ) echo "Please answer y or n.";;
                        esac
		done

	else
     		addcert=true
   	fi
   	if [ "$addcert" = true ];then
		echo ""
		echo "Generating and adding cert for $vhost..."
        	java utils.CertGen -cn $vhost -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $KEYPASS -certfile $vhost.cert -keyfile $vhost.key -domain $ASERVER -nosanhostdns -a $final_sanurl -validuntil "2030-03-01" >> $KEYSTORE_HOME/$vhost/$vhost.CertGen.$dt.log 2>&1
        	java  utils.ImportPrivateKey -certfile $ASERVER/security/$vhost.cert.der -keyfile $ASERVER/security/$vhost.key.der -keyfilepass $KEYPASS -keystore $KEYSTORE_HOME/appIdentityKeyStore.$storetype -storepass $KEYPASS -alias $vhost -keypass $KEYPASS  -storetype $storetype  >> $KEYSTORE_HOME/$vhost/$vhost.ImportPrivateKey.$dt.log 2>&1
		echo ""
		echo "Updating orapki wallet with new cert..."
                if [ -d $KEYSTORE_HOME/orapki ]; then
                        echo "Root orapki wallet already exists, adding just the new cert... "
                else
                        echo "Root orapki wallet does not exist, creating it and adding the new certs for WLS access..."
			mkdir -p  $KEYSTORE_HOME/orapki/
			$WL_HOME/../bin/orapki wallet create -wallet $KEYSTORE_HOME/orapki/ -auto_login_only
			$WL_HOME/../bin/orapki wallet jks_to_pkcs12 -wallet  $KEYSTORE_HOME/orapki/ -keystore $KEYSTORE_HOME/appTrustKeyStore.$storetype -jkspwd $KEYPASS
                fi
		rm -rf $KEYSTORE_HOME/orapki/orapki-vh-$vhost
		mkdir -p $KEYSTORE_HOME/orapki/orapki-vh-$vhost
		echo ""
		$WL_HOME/../bin/orapki wallet create -wallet $KEYSTORE_HOME/orapki/orapki-vh-$vhost -auto_login_only
		$WL_HOME/../bin/orapki wallet jks_to_pkcs12 -wallet $KEYSTORE_HOME/orapki/orapki-vh-$vhost -keystore $KEYSTORE_HOME/appIdentityKeyStore.$storetype -jkspwd $KEYPASS -aliases $vhost
		$WL_HOME/../bin/orapki wallet jks_to_pkcs12 -wallet  $KEYSTORE_HOME/orapki/orapki-vh-$vhost -keystore $KEYSTORE_HOME/appTrustKeyStore.$storetype -jkspwd $KEYPASS
    	fi
done
cd $KEYSTORE_HOME
tar -czf  $KEYSTORE_HOME/orapki-ohs.tgz ./orapki
echo""
echo "***********************************************************************************************"
echo "***********************************************************************************************"
echo "Tar to ship to Oracle HTTP Server nodes: "
echo "		- $KEYSTORE_HOME/orapki-ohs.tgz"
echo "***********************************************************************************************"
echo "***********************************************************************************************"

echo ""
rm -rf /tmp/config-nons.xml
