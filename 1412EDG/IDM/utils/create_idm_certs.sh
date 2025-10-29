#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used to create self issued certificates for an Oracle Identity Management deployment
#
# Usage: create_idm_certs.sh [-c ca_file] [-t host | SAN | WILD] [ -p Keystore Password ]  [ -a Other CAs ] [ -o overwrite ] [-h help]
#

. hostlist.txt
rm idmcerts.log >/dev/null 2>&1
create_ca()
{
	echo "Creating Certificate Authority: idmCa.crt"

        openssl genrsa -out idmCA.key 4096 >> idmcerts.log
        openssl req -x509 -new -key idmCA.key -out idmCA.crt -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=IDM Certificate Authority/" -days 50000 -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" -addext "subjectKeyIdentifier=hash"  >> idmcerts.log
}

create_host_cert()
{  
	host=$1
	echo "Generating Certificate for $host"
	openssl genrsa -out $host.key 4096 >> idmcerts.log 2>&1
        openssl req -new -key $host.key -out $host.csr -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=$host" >> idmcerts.log 2>&1
        openssl x509 -req -in $host.csr -CA idmCA.crt -CAkey idmCA.key -CAcreateserial -out $host.crt -days 30000 >> idmcerts.log 2>&1
}

create_san_cert()
{  
	hosts=$(echo $1 | sed "s/,/ /g")
	cert_name=$2

	echo "Generating SAN Certificate $cert_name for $hosts"
	if [ -e $cert_name.cnf ] 
	then
	   echo -n "SAN Certificate already exists - "
	   if [ "$OVERWRITE" = "true" ]
	   then
	     echo "Overwriting certificate."
	     rm $cert_name.* >> idmcerts.log 2>&1
	   else
             echo "Keeping certifcate and exiting. Specify -o to overwrite"
	     exit
	   fi
	fi
	inx=1
	for host in $hosts
	do
           if [ "$CA_TYPE" = "WILD" ]
           then
	      if [ ! -e $cert_name.cnf ]
              then
                sed "s/<CN>/*.$host/" ../cert.cnf > $cert_name.cnf
	      fi
              echo "DNS.$inx   = $host" >> $cert_name.cnf
	      inx=$((inx+1))
              echo "DNS.$inx   = *.$host" >> $cert_name.cnf
           else
	      if [ ! -e $cert_name.cnf ]
              then
                sed "s/<CN>/$host/" ../cert.cnf > $cert_name.cnf
	      fi
              echo "DNS.$inx   = $host" >> $cert_name.cnf
           fi
	   inx=$((inx+1))
	done
	echo "openssl genrsa -out $cert_name.key 4096" >> idmcerts.log 2>&1
	openssl genrsa -out $cert_name.key 4096 >> idmcerts.log 2>&1
        echo openssl req -new -key idmCA.key -out $cert_name.csr -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=$cert_name" -config $cert_name.cnf >> idmcerts.log 2>&1
        openssl req -new -key $cert_name.key -out $cert_name.csr -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=$cert_name" -config $cert_name.cnf -addext "subjectAltName = DNS:$cert_name">> idmcerts.log 2>&1
        echo openssl x509 -req -in $cert_name.csr -CA idmCA.crt -CAkey idmCA.key -CAcreateserial -out $cert_name.crt -days 30000 -setalias $cert_name>> idmcerts.log 2>&1
        openssl x509 -req -in $cert_name.csr -CA idmCA.crt -CAkey idmCA.key -CAcreateserial -out $cert_name.crt -days 30000 -setalias $cert_name -extfile $cert_name.cnf -extensions v3_req>> idmcerts.log 2>&1
}
convert_cert_p12()
{
   cert=$1
   keypass=$2
   certsn=$(echo $cert | cut -f1 -d.)
   echo "Converting Certificate $cert to PKCS12"
   echo openssl pkcs12 -export -out $cert.p12 -inkey idmCA.key -in $cert.crt -chain -CAfile idmCA.crt -passout pass:$keypass name $certsn>> idmcerts.log 2>&1
   openssl pkcs12 -export -out $cert.p12 -inkey $cert.key -in $cert.crt -chain -CAfile idmCA.crt -passout pass:$keypass -name $certsn>> idmcerts.log 2>&1
}

create_trust_store()
{ 
    echo "Creating trust store idmTrustStore.p12"
    keytool -import -keystore idmTrustStore.p12 -alias idmCA-cert -rfc -file idmCA.crt -storepass $KEY_PASS -storetype pkcs12 -noprompt >> idmcerts.log
    if [ ! "$TRUSTCAS" = "" ]
    then
      TRUSTCAS=$(echo $TRUSTCAS | sed 's/,//g')
      for ca in $TRUSTCAS
      do
         echo "Adding $ca to idmTrustStore.p12"
         keytool -import -keystore idmTrustStore.p12 -alias $(basename $ca | cut -f1 -d.)-cert -rfc -file $ca -storepass $KEY_PASS -storetype pkcs12 -noprompt >> idmcerts.log 2>&1
      done
    fi
}

create_keystore()
{ 
    certName=$1
    cert=$2
    echo "Creating Keystore idmcerts.p12"
    keytool -importkeystore -srckeystore $cert.p12 -srcstoretype PKCS12 -destkeystore $certName.p12 -deststoretype PKCS12 -storepass $KEY_PASS  -srcstorepass $KEY_PASS >> idmcerts.log 2>&1
}

while getopts 'c:t:p:a:oh' OPTION
do
  case "$OPTION" in
    c)
      CA_FILE=$OPTARG
      echo "CA File specified: $CA_FILE"
     ;;
    t)
      CA_TYPE=$OPTARG
     ;;
    p)
      KEY_PASS=$OPTARG
     ;;
    a)
      TRUSTCAS=$OPTARG
     ;;
    o)
      OVERWRITE=true
     ;;
    h)
      echo "This script generates self issued certificates for Oracle Identity Management Deployments."
      echo ""
      echo "script usage: $(basename $0) [-c ca_file] [-t host | SAN | WILD] [ -p Keystore Password ]  [ -a Other CAs ] [ -o overwrite ] [-h help] " >&2
      echo 
      echo " -c Specify the name of an existing CA certificate you wish to use to sign your new certificates.   If you do not specify this then a new one will be created called idmCA.crt unless it already exists at which point it will be reused"
      echo 
      echo " -t type, the type of certificate to generate:  host - generate a certificate for every host. With the exception of ldap and OHS hosts which will be SAN certificates with the host and load balancer names included"
      echo 
      echo " -p Keystore Password, a password used to secure the keystore.  It should not be a password used by any other accounts in the Identity Management deployment"
      echo 
      echo "-a A comma separated list of certificate authority files which you wish added to the generated trust store, for example the certificate authority used to issue load balancer certificates."
      echo
      echo "-o overwrite any existing SAN certificates which may exist.  This will not overwrite an existing CA file."
      echo
      echo "Optionally Complete the file hostlist.txt to save having to re-enter hostnames."

     exit
     ;;
    ?)
     echo "script usage: $(basename $0) [-c ca_file] [-t host | SAN | WILD] [ -p Keystore Password ]  [ -a Other CAs ] [ -o overwrite ] [-h help] " >&2
     exit 1
     ;;
   esac
done

mkdir idmcerts > /dev/null 2>&1
cd idmcerts
rm idmcerts.log > /dev/null 2>&1

if [ "$CA_TYPE" = "" ] 
then
    echo -n "Enter Certificate Type (host/SAN):"
    read CA_TYPE
fi

if [ "$KEY_PASS" = "" ] 
then
    echo -n "Enter Keystore Password:"
    read KEY_PASS
fi


if [ "$CA_FILE" = "" ] 
then
   if [ ! -e idmCA.crt ]
   then
       create_ca
   else
       echo "CA Already Exists."
   fi
fi

if  [ "$OAMHOSTS" = "" ]
then
  echo -n "Enter a comma separated list of your OAM Hosts including virtual hosts:"
  read OAMHOSTS
fi

if  [ "$OIGHOSTS" = "" ]
then
  echo -n "Enter a comma separated list of your OIG Hosts including virtual hosts:"
  read OIGHOSTS
fi
if  [ "$LDAPHOSTS" = "" ]
then
  echo -n "Enter a comma separated list of your LDAP Hosts:"
  read LDAPHOSTS
fi
if  [ "$LDAPHOST_LBR" = "" ]
then
  echo -n "Enter the Load Balancer Name for your LDAP Directory:"
  read LDAPHOST_LBR
fi
if  [ "$OHSHOSTS" = "" ]
then
  echo -n "Enter a comma separated list of your Web Hosts:"
  read OHSHOSTS
fi
if  [ "$LBRHOSTS" = "" ]
then
  echo -n "Enter a comma separated list of your Load Balancer listen host names:"
  read LBRHOSTS
fi

if [ "$CA_TYPE" = "host" ] || [ "$CA_TYPE" = "" ]
then

    echo "Generating Host based Certs for oamhosts and oighosts"
    HOSTLIST=$(echo "$OAMHOSTS $OIGHOSTS" |sed "s/,/ /g")
    for certHost in $HOSTLIST
    do
      create_host_cert $certHost
      convert_cert_p12 $certHost $KEY_PASS
      create_keystore wlscerts $certHost 
    done

    echo "Generating SAN based Certs for ldaphosts"
    LDAPHosts=$(echo "$LDAPHOSTS" |sed "s/,/ /g")
    for ldapHost in $LDAPHosts
    do
      create_san_cert "$LDAPHOST_LBR $ldapHost" $ldapHost
      convert_cert_p12 $ldapHost $KEY_PASS
    done

    echo "Generating SAN based Certs for webhosts"
    LBRHosts=$(echo "$LBRHOSTS" |sed "s/,/ /g")
    OHSHosts=$(echo "$OHSHOSTS" |sed "s/,/ /g")
    for lbrhost in $LBRHosts
    do
       for ohsHost in $OHSHosts
       do
         create_san_cert "$lbrhost $ohsHost" $lbrhost.$ohsHost
         convert_cert_p12 $lbrhost.$ohsHost $KEY_PASS
       done
    done

elif [ "$CA_TYPE" = "SAN" ]
then
    create_san_cert "$LDAPHOSTS $LDAPHOST_LBR $OAMHOSTS $OIGHOSTS $OHSHOSTS $LBRHOSTS" idmcerts
    convert_cert_p12 idmcerts $KEY_PASS

elif [ "$CA_TYPE" = "WILD" ] 
then
   if  [ "$WILDHOSTS" = "" ]
   then
     echo -n "Enter a comma separated list of your wildcard domains, for Kubernetes this will look like <namespace>.svc.cluster.local do not include the *: "
     read WILDHOSTS
   fi

    echo "Generating Wildcard based Certs"
    HOSTLIST=$(echo "$WILDHOSTS" |sed "s/,/ /g")

    HOSTLIST=$(echo "$HOSTLIST" |sed "s/,/ /g")
    for wildHost in $HOSTLIST
    do
      create_san_cert "$wildHost" $wildHost
      convert_cert_p12 $ldapHost $KEY_PASS
    done

fi
	
create_trust_store
