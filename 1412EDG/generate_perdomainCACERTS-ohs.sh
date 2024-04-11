export ohshostname1=$1
export ohshostname2=$2
export keypass=$3

export ASERVER=/u01/oracle/config/domains/soast32edg
export KEYSTORE_HOME=/u01/oracle/config/keystores/
export WL_HOME=/u01/oracle/products/fmw/wlserver
export JAVA_HOME=/u01/oracle/products/jdk
export PATH=$JAVA_HOME/bin:$PATH

cd $KEYSTORE_HOME

. $WL_HOME/server/bin/setWLSEnv.sh

sed -e 's/xmlns="[^"]*"//g' $ASERVER/config/config.xml >/tmp/config-nons.xml

#export totalstr=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-host")
export teststrt=$(xmllint /tmp/config-nons.xml --xpath  "//frontend-host"  | tr -d '[:space:]' | sed -e 's/<\/frontend-host>/\n/g' | awk -F'<frontend-host>' '{print $2}' |   awk '!x[$0]++' | awk '{print "DNS:"$1}')

export newtotalst="${teststrt//$'\n'/,}"
#export totalstr=$(cat $ASERVER/config/config-nons.xml | grep  frontend-host | awk -F "<frontend-host>" '{print $2}' | awk -F "</frontend-host>" '{print "DNS:"$1}'|   awk '!x[$0]++')
#newtotalst="${totalstr//$'\n'/,}"
echo "Resulting DNS= $newtotalst"

java utils.CertGen -cn $ohshostname1 -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $keypass -certfile $ohshostname1.cert -keyfile $ohshostname1.key -domain $ASERVER -selfsigned -nosanhostdns -a $newtotalst

java utils.CertGen -cn $ohshostname2 -keyusagecritical "true" -keyusage "digitalSignature,nonRepudiation,keyEncipherment,keyCertSign,dataEncipherment,keyAgreement" -keyfilepass $keypass -certfile $ohshostname2.cert -keyfile $ohshostname2.key -domain $ASERVER -selfsigned -nosanhostdns -a $newtotalst

keytool -delete -alias $ohshostname1 -storepass  $keypass -keystore appIdentityKeyStore.jks

keytool -delete -alias $ohshostname2 -storepass  $keypass -keystore appIdentityKeyStore.jks

java  utils.ImportPrivateKey -certfile $ASERVER/security/$ohshostname1.cert.der -keyfile $ASERVER/security/$ohshostname1.key.der -keyfilepass $keypass -keystore appIdentityKeyStore.jks -storepass $keypass -alias $ohshostname1 -keypass $keypass

java  utils.ImportPrivateKey -certfile $ASERVER/security/$ohshostname2.cert.der -keyfile $ASERVER/security/$ohshostname2.key.der -keyfilepass $keypass -keystore appIdentityKeyStore.jks -storepass $keypass -alias $ohshostname2 -keypass $keypass

rm -rf /tmp/config-nons.xml

