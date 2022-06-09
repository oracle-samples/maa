#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

BASHRC_FILE=/home/oracle/.bashrc

if [ ! -f $BASHRC_FILE ]; then
    echo "File [$BASHRC_FILE] not found!"
    exit -1
fi

DOMAIN_HOME=$(awk -F= '/DOMAIN_HOME=/ {print $2}' $BASHRC_FILE)
TOKENS_FILE="${DOMAIN_HOME}/init-info/tokenValue.properties"

WL_HOME=$(grep '@WL_HOME=' ${TOKENS_FILE} | awk -F= '{print $2}')

echo ${WL_HOME}
