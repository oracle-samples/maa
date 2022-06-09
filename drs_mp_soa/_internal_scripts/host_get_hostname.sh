#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
FULL_HOSTNAME=$(/bin/hostname -f)
echo "FULL HOSTNAME=${FULL_HOSTNAME}"
# does not always work # IFCONFIG_OUT=$(ifconfig eth0)
# does not always work # IP_ADDR=$(${IFCONFIG_OUT} | awk '/inet addr/ {gsub("addr:", "", $2); print $2}')
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "IP_ADDRESS=${IP_ADDR}"
