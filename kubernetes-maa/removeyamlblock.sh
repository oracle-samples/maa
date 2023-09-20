#!/bin/bash


## removeyamlblock.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script will "clean-up" a yaml block 
### The namespaces list is obtained from the directory structure in the TAR
### Usage:
###
###      ./removeyamlblock.sh [YAML_FILE] [ROOT_ITEM] [SUBITEM_TO_REMOVE]
### Where:
###     YAML_FILE
###                     The YAML file that will be modified
###		ROOT_ITEM
###			The root context where the subitem is located
###		SUBITEM_TO_REMOVE
###			The yaml block under root context that will be removed

export file=$1
export inrootblock=$2
export indeleteblock=$3
export rootblock="$inrootblock:"
export deleteblock="$indeleteblock:"

tmpfile=$(mktemp)
cp $file "$tmpfile" 
awk -v rb="$rootblock" -v db="$deleteblock" '$1 == rb{t=1}
   t==1 && $1 == db{t++; next}
   t==2 && /:[[:blank:]]*$/{t=0}
   t != 2' $tmpfile >$file
rm $tmpfile
