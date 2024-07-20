#!/bin/sh
############################################################################
#
# File name:   startWS.sh   Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# 
# Description: Start the PeopleSoft PIA / WLS server
# 
# Usage:       startWS.sh <domain>
# 
# Errors:
#
# Revisions:
# Date       Who
# 7/1/2023   DPresley
############################################################################

# Start the PeopleSoft PIA.
  
source ~/psft.env

DOMAIN="$1"
DOMAIN_DIR="${PS_CFG_HOME}/webserv"
RC=0

# get the length of the parameter
n=${#DOMAIN}

# Did they pass in a parameter?  it is the domain
if [ "$n" != 0 ]; then
   echo "Domain passed in as parameter: $DOMAIN"
else
   echo "No domain passed in. Look for single WLS Server domain."
   DOMAIN="$("$SCRIPT_DIR"/get_ps_domain.sh "${DOMAIN_DIR}")"
   RC=$?
   if [ ${RC} != 0 ]; then
        [[ ${RC} = 1 ]] && echo "Domain directory ${DOMAIN_DIR} does not exists."
        [[ ${RC} = 2 ]] && echo "Domain directory ${DOMAIN_DIR} contains either no domains or more than one domain."
        exit ${RC}
   fi
fi

# Is the domain set?
if [ "$DOMAIN" = "" ]; then
   echo "Domain not set. Stopping run."
   exit 1
fi

HOSTNAME="$(hostname)"

date
echo "------ Starting WLS Server for domain: $DOMAIN on host: $HOSTNAME ----"
"${PS_CFG_HOME}"/webserv/"${DOMAIN}"/bin/startPIA.sh
