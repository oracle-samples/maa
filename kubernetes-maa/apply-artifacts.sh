#!/bin/bash


## apply-artifact.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script will "clean-up" and apply a yaml to a K8s cluster checking first if it already exisit
### The namespaces list is obtained from the directory structure in the TAR
### Usage:
###
###      ./apply-artifact.sh [YAML FILE] [LOG FILE]
### Where:
###     YAML FILE
###                     The YAML that will be applied
###	LOG FILE
###			The log file to store result and info

artifact=$1
oplog=$2


echo "Here goes $artifact" >> $oplog
sed -i '/creationTimestamp: /d' $artifact
sed -i '/resourceVersion: /d' $artifact
sed -i '/uid: /d' $artifact
sed -i '/clusterIP: /,+2d' $artifact
sed -i '/nodeName: /d' $artifact
$basedir/removeyamlblock.sh $artifact metadata ownerReferences
#In preparation for avoiding secrets to be copied
#sed -i '/secrets:/,+2d' $artifact
cat $artifact >> $oplog
create_result=$(kubectl create -f $artifact --validate=false 2>&1)
if [[ "$create_result" == *"AlreadyExists"* ]]; then
	echo "Artifacts exists. Replacing instead..." >> $oplog
	kubectl replace -f $artifact --validate=false
elif [[ "$create_result" == *"Error"* ]]; then
	echo "An unknown error ocurred check artifact $artifact ..." >> $oplog
	echo "$create_result" >> $oplog
else
	echo "Creation of artifact succeeded": >> $oplog
	echo "$create_result" >> $oplog
fi

