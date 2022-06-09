#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

#
# Get the full hostname.
FULL_HOSTNAME=$(/bin/hostname -f)
echo "FULL_HOSTNAME=${FULL_HOSTNAME}"

#
# Get the IP address (commented out versions don't work reliably)
# does not always work # IFCONFIG_OUT=$(ifconfig eth0)
# does not always work # IP_ADDR=$(${IFCONFIG_OUT} | awk '/inet addr/ {gsub("addr:", "", $2); print $2}')
IP_ADDRESS=$(hostname -I | awk '{print $1}')
echo "IP_ADDRESS=${IP_ADDRESS}"

#
# Get the OS version
OS_VERSION=$(cat /etc/oracle-release | grep "Oracle Linux Server release" | awk '{print $5}')
echo "OS_VERSION=${OS_VERSION}"

