#!/bin/bash

##  import-domainca-into-kss.sh script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script imports the per-WLS-domain CA certificate into FMW KSS and updates the configuraton of KSS to use this for jps configuration.
### It needs an existing FMW/WLS installation (required for setting JAVA_HOME, WL_HOME etc).
### It requires customizing some variables according to the environment.
### It also needs the domain and trustore password to connect through SSL to the administration server for the updates.
### Notice that if you used the scripts provided in the EDG to generate certs and stores, DOMAINPASS and KEYPASS are the same.
### Usage:
###
###      	./import-domainca-into-kss.sh [DOMAIN_PASS] [KEYPASS]
### Where:
###		DOMAIN_PASS:
###			 The password for the admin user that will update the domain.
###		KEYPASS:
###			Password used to access the TustTore file configured for the domain.

############# CUSTOMIZE THESE VARIABLES ACORDING TO YOUR ENVIRONMENT #############
export DOMAIN_HOME=/u01/oracle/config/domains/soast32edg
export MW_HOME=/u01/oracle/products/fmw
export ADMINVHN=asvip.soaedgtest.paasmaaoracle.com
export ADMINPORT=9002
export DOMAINUSER=soast32edgadmin
export TRUSTSTOREFILE=/u01/oracle/config/keystores/appTrustKeyStore.jks
############# END OF VARIABLE CUSTOMIZATION #############

if [[ $# -eq 2 ]];
then
	export DOMAINPASS=$1
	export KEYPASS=$2

else
	echo ""
	echo "ERROR: Incorrect number of parameters used: Expected 2, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [DOMAINPASS] [KEYPASS]"
	echo ""
	echo "Example:  "
	echo "    $0 domainadminpassword123 mycertkeystorepass123"
	exit 1
fi

export dt=`date +%y-%m-%d-%H-%M-%S`
export alias="domainca-new-$dt"

. $MW_HOME/wlserver/server/bin/setWLSEnv.sh

rm -rf /tmp/update.py
rm -rf /tmp/democa-from-securityder.crt

echo "Generating domain ca cert from domain der..."
openssl x509 -inform der -in $DOMAIN_HOME/security/democacert.der -outform PEM -out  /tmp/democa-from-securityder.crt

cat <<EOF >>/tmp/update.py
connect('$DOMAINUSER','$DOMAINPASS','t3s://$ADMINVHN:$ADMINPORT')
svc = getOpssService(name='KeyStoreService')
svc.importKeyStoreCertificate(appStripe='system', name='trust', password='$DOMAINPASS', alias='$alias', keypassword='$KEYPASS', type='TrustedCertificate', filepath='/tmp/democa-from-securityder.crt')
svc.listKeyStoreAliases(appStripe='system', name='trust', password='$DOMAINPASS', type='TrustedCertificate')
domainRuntime()
val = None
key = None
si  = None
for  i in range(len(sys.argv)):
    if sys.argv[i] == "-si":
        si = sys.argv[i+1]
    if sys.argv[i] == "-key":
        key = sys.argv[i+1]
    if sys.argv[i] == "-value":
        val = sys.argv[i+1]
on = ObjectName("com.oracle.jps:type=JpsConfig")
sign = ["java.lang.String", "java.lang.String","java.lang.String"]
params = [si,key,val]
mbs.invoke(on,"updateServiceInstanceProperty", params, sign)
mbs.invoke(on, "persist", None, None)
EOF
export WLST_PROPERTIES="-Dweblogic.security.TrustKeyStore=CustomTrust -Dweblogic.security.CustomTrustKeyStoreFileName=$TRUSTSTOREFILE -Dweblogic.security.CustomTrustKeyStorePassPhrase=$KEYPASS"

$MW_HOME/oracle_common/common/bin/wlst.sh /tmp/update.py -si keystore.db -key ca.key.alias -value $alias

rm  /tmp/update.py
rm  /tmp/democa-from-securityder.crt
