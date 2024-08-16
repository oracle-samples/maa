#!/bin/sh
############################################################################
#
# File name: startCacheServer.sh  Version 1.0
# 
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Start Coherence*Web cache server
# 
# Usage: startCacheServer.sh <PeopleSoft coherence domain>
#        We don't have a good way to derive the domain name/build a 
#        directory location for Coherence*Web log files, so it is
#        required.
# 
# Errors: Could not determine Coherence domain
#
# Revisions:
# Date       Who       What
# 7/1/2023   DPresley  Created
############################################################################

source ~/psft.env

DOMAIN="$1"

# get the length of the parameter
n=${#DOMAIN}

# Did they pass in a parameter?  it is the domain
if [ "$n" != 0 ]; then
   echo "Domain passed in as parameter: ${DOMAIN}"
else
   echo "No domain passed in. Domain required."
   exit 1
fi

HOSTNAME="$(hostname)"
COHERENCE_HOME="${BASE_DIR}"/pt/bea/coherence
COHERENCE_CONFIG="${PS_CFG_HOME}"/coherence/config
COHERENCE_LOG="${PS_CFG_HOME}"/coherence/log
CWEB_LOG_NAME=pia_"${DOMAIN}"_"${HOSTNAME}"
CWEB_LOG_LEVEL=9

date
echo "------ Starting Coherence*Web Cache Server for domain: $DOMAIN on host: $HOSTNAME ----"

echo ""
echo "tangosol.coherence.override=${COHERENCE_CONFIG}/tangosol-coherenceoverride.xml"
echo "Log file can be found at: ${COHERENCE_LOG}/cweb_coherence_server_${CWEB_LOG_NAME}.log"

java -Xms2g -Xmx2g -Dtangosol.coherence.distributed.localstorage=true -Dtangosol.coherence.session.localstorage=true -Dtangosol.coherence.override="${COHERENCE_CONFIG}"/tangosol-coherence-override.xml -Dtangosol.coherence.cacheconfig=default-session-cache-config.xml -Dtangosol.coherence.log="${COHERENCE_LOG}"/cweb_coherence_server_"${CWEB_LOG_NAME}".log -Dtangosol.coherence.log.level=9 -classpath "${COHERENCE_CONFIG}":"${COHERENCE_HOME}"/lib/coherence.jar:"${COHERENCE_HOME}"/lib/coherence-web.jar com.tangosol.net.DefaultCacheServer -Djava.net.preferIPv6Addresses=false -Djava.net.preferIPv4Stack=true -Dcoherence.log.level="${CWEB_LOG_LEVEL}"  &

