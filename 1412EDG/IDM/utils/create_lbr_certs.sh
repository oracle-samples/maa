#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script which can be used create self-issued certificates for Load Balancers 
# used in and Oracle Identity Management Deployment
#
#
# Usage: provision_oam.sh  [-r responsefile -p passwordfile]
#


create_host_cert()
{
        host=$1
        echo "Generating Certificate for $host"
	openssl genrsa -out $host.key 4096 >> lbrcerts.log 2>&1
        openssl req -new -key $host.key -out $host.csr -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=$host" >> lbrcerts.log 2>&1
        openssl x509 -req -in $host.csr -CA lbrCA.crt -CAkey lbrCA.key -CAcreateserial -out $host.crt -days 30000 >> lbrcerts.log 2>&1
}

convert_cert_p12()
{
   cert=$1
   echo "Converting Certificate to PKCS12"
   echo openssl pkcs12 -export -out $cert.p12 -inkey lbrCA.key -in $cert.crt -chain -CAfile lbrCA.crt -passout pass:$KEYPASS>> lbrcerts.log 2>&1
   openssl pkcs12 -export -out $cert.p12 -inkey $cert.key -in $cert.crt -chain -CAfile lbrCA.crt -passout pass:$KEYPASS -name $cert>> lbrcerts.log 2>&1
}
create_ca()
{
        echo "Creating Certificate Authority: lbrCA.crt"

        openssl genrsa -out lbrCA.key 4096 >> lbrcerts.log
        openssl req -x509 -new -key lbrCA.key -out lbrCA.crt -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=LBR Certificate Authority/" -days 50000   -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" -addext "subjectKeyIdentifier=hash" >> lbrcerts.log
}

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while getopts 'h:p:' OPTION
do
  case "$OPTION" in
    h)
      HOSTLIST=$OPTARG
     ;;
    p)
      KEYPASS=$OPTARG
     ;;
    ?)
     echo "script usage: $(basename $0) [-h hosts -p Keystore password] " >&2
     exit 1
     ;;
   esac
done

mkdir lbr_certs > /dev/null 2>&1
echo "Certificates will be generated in the directory lbr_certs"
echo 
cd lbr_certs
if [ "$CA_FILE" = "" ]
then
   if [ ! -e lbrCA.crt ]
   then
       create_ca
   else
       echo "CA Already Exists."
   fi
fi

if [ "$HOSTLIST" = "" ]
then
   echo -n "Enter a comma separated list of host names :"
   read HOSTLIST
fi

if [ "$KEYPASS" = "" ]
then
   echo -n "Enter a keystore password :"
   read -s KEYPASS
fi
HOSTLIST=$(echo $HOSTLIST | sed "s/,/ /g")
echo "Creating Host Certs"

rm lbrcerts.log >/dev/null 2>&1

for host in $HOSTLIST
do
  create_host_cert $host
  convert_cert_p12 $host 
done

echo "Creating SAN Cert"
openssl genrsa -out lbrSAN.key 4096 >> lbrcerts.log 2>&1
inx=1
for host in $HOSTLIST
do
   if [ $inx -eq 1 ]
   then
      sed "s/<CN>/$host/" ../cert.cnf > lbr.cnf
   fi
   echo "DNS.$inx   = $host" >> lbr.cnf
   inx=$((inx+1))
done

openssl req -new -key lbrSAN.key -out lbrSAN.csr -subj "/C=us/ST=ca/L=Redwood Shores/O=Oracle/CN=lbrSAN" -config lbr.cnf -addext "subjectAltName = DNS:lbrSAN"
openssl x509 -req -in lbrSAN.csr -CA lbrCA.crt -CAkey lbrCA.key -CAcreateserial -out lbrSAN.crt -days 30000 -extfile lbr.cnf -extensions v3_req

