#!/bin/bash

## fmwadbs_rest_api_listabds.sh script version 1.0.
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script is used to obtain the Autonomous Database role base on the ADB ID and tenancy information.
### It uses REST APIS to query OCI endpoints of the ADB service
### Refer to https://docs.oracle.com/en-us/iaas/Content/API/Concepts/usingapi.htm for more details

### Usage:
###
###      ./fmwadbs_rest_api_listabds.sh [TENANCY_OCID] [USER_OCID] [PRIVATE_KEY] [ADB_OCID]
### Where:
###	TENANCY_OCID:
###			This is the OCID of the tenancy where the ADBS resides. It can be obtained from the OCI UI
###			Refer to https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/contactingsupport_topic-Finding_Your_Tenancy_OCID_Oracle_Cloud_Identifier.htm
###	USER_OCID:		
###			This is the OCID of the user owning the ADB instance. It can be obtained from the OCI UI.
###			Refer to https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/contactingsupport_topic-Finding_Your_Tenancy_OCID_Oracle_Cloud_Identifier.htm
###	PRIVATE_KEY:
### 			Path to the private PEM format key for this user
### 			Refer to https://docs.oracle.com/en-us/iaas/Content/API/Concepts/apisigningkey.htm for details
###	ADB_OCID:
###			This is the OCID of the ADBS being inspected. The ADB OCID can be obtained from the ADB screen in OCI UI
### EXAMPLE:
###
###    ./fmwadbs_rest_api_listabds.sh    "ocid1.tenancy.oc1..aaaaaaaa7dkeohv7arjwvdgobyqml2ZZZZZZZZZZZZZZZZZZZZZZ" "ocid1.user.oc1..aaaaaaaaz76qxwxdekcnwaza5zXXXXXXXXXXXXXXXXXXXX"  "/share/oracleidentitycloudservice.pem"  ocid1.autonomousdatabase.oc1.ap-hyderabad-1.anuhsljrj4yyyyyyyyyyyyyyyyyyyyyy"

###----------------------------------INFORMATION GATHERED---------------------------------
### DATABASE NAME .............................: soaadb1
### DATABASE ROLE .............................: STANDBY
### DATABASE isDataGuardEnabled................: false
### DATABASE RemoteDataGuardEnabled ...........: false
### DATABASE isLocalDataGuardEnabled...........: false
### DATABASE isRefreshableClone ...............: null
### DATABASE CONNECT STRINGS ..................:
### {
###   "HIGH": "adb.ap-hyderabad-1.oraclecloud.com:1522/g914a2540e8ab6d_soaadb1_high.adb.oraclecloud.com",
###   "MEDIUM": "adb.ap-hyderabad-1.oraclecloud.com:1522/g914a2540e8ab6d_soaadb1_medium.adb.oraclecloud.com",
###   "LOW": "adb.ap-hyderabad-1.oraclecloud.com:1522/g914a2540e8ab6d_soaadb1_low.adb.oraclecloud.com",
###   "TPURGENT": "adb.ap-hyderabad-1.oraclecloud.com:1522/g914a2540e8ab6d_soaadb1_tpurgent.adb.oraclecloud.com",
###   "TP": "adb.ap-hyderabad-1.oraclecloud.com:1522/g914a2540e8ab6d_soaadb1_tp.adb.oraclecloud.com"
### }


if [[ $# -eq 4 ]]; then
	export TENANCY_OCID=$1
	export USER_OCID=$2
	export PRIVATE_KEY=$3
	export ADB_OCID=$4
else
	echo ""
	echo "ERROR: Incorrect number of parameters used. Expected 2, got $#"
	echo "Usage :"
	echo "    $0 TENANCY_OCID USER_OCID PRIVATE_KEY ADB_OCID"NCY_OCID:
	echo "Example:  "
	echo "    $0 "ocid1.tenancy.oc1..aaaaaaaa7dkeohv7arjwvdgobyqml2ZZZZZZZZZZZZZZZZZZZZZZ" "ocid1.user.oc1..aaaaaaaaz76qxwxdekcnwaza5zXXXXXXXXXXXXXXXXXXXX"  "/u01/soacs/dbfs/share/oracleidentitycloudservice.pem"  ocid1.autonomousdatabase.oc1.ap-hyderabad-1.anuhsljrj4yyyyyyyyyyyyyyyyyyyyyy "
	echo ""
	exit 1
fi

# The following fields are dynamically constructed and it is not needed to change them

api_region=$(echo $ADB_OCID  | awk -F'.' '{print $4}')
api_host=database.${api_region}.oraclecloud.com
fingerprint=$(openssl rsa -pubout -outform DER -in "$PRIVATE_KEY"  2>/dev/null | openssl md5 -c | awk -F '= ' '{print $2}')
rest_api="/20160918/autonomousDatabases/$ADB_OCID"
date=`date -u "+%a, %d %h %Y %H:%M:%S GMT"`
date_header="date: $date"
host_header="host: $api_host"
request_target="(request-target): get $rest_api"
signing_string="$request_target\n$date_header\n$host_header"
headers="(request-target) date host"
signature=`printf '%b' "$signing_string" | openssl dgst -sha256 -sign $PRIVATE_KEY | openssl enc -e -base64 | tr -d '\n'`
export result=$(curl -X GET https://$api_host$rest_api -H "date: $date" -H "Authorization: Signature version=\"1\",keyId=\"$TENANCY_OCID/$USER_OCID/$fingerprint\",algorithm=\"rsa-sha256\",headers=\"$headers\",signature=\"$signature\""  -sS)

echo "----------------------------------INFORMATION GATHERED---------------------------------"

export dbname=$(printf '%b' $result | jq -r '.dbName')
export role=$(printf '%b' $result | jq -r '.role')
export isDataGuardEnabled=$(printf '%b' $result | jq -r '.isDataGuardEnabled')
export isRemoteDataGuardEnabled=$(printf '%b' $result | jq -r '.isRemoteDataGuardEnabled')
export isLocalDataGuardEnabled=$(printf '%b' $result | jq -r '.isLocalDataGuardEnabled')
export isRefreshableClone=$(printf '%b' $result | jq -r '.isRefreshableClone')
export refreshableMode=$(printf '%b' $result | jq -r '.refreshableMode')
export allConnectionStrings=$(printf '%b' $result | jq -r '.connectionStrings.allConnectionStrings')

echo "DATABASE NAME .............................: $dbname"
echo "DATABASE ROLE .............................: $role"
echo "DATABASE isDataGuardEnabled................: $isDataGuardEnabled"
echo "DATABASE RemoteDataGuardEnabled ...........: $isRemoteDataGuardEnabled"
echo "DATABASE isLocalDataGuardEnabled...........: $isLocalDataGuardEnabled"
echo "DATABASE isRefreshableClone ...............: $isRefreshableClone"
echo "DATABASE CONNECT STRINGS ..................:"
echo "$allConnectionStrings"
echo "---------------------------------------------------------------------------------------"

