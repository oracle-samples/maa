#!/bin/bash
############################################################################
#
# File name: stopAPP.sh   Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Stop the PSFT application servers
# 
# Usage: stopAPP.sh <app server domain>
#        If no parameter, look in $PS_CFG_HOME/appserv for the domain
# 
# Errors: Domain not set
#         More than one domain found.
#
############################################################################

source ~/psft.env

DOMAIN="$1"
DOMAIN_DIR="${PS_CFG_HOME}/appserv"
RC=0

# get the length of the parameter
n=${#DOMAIN}

# Did they pass in a parameter?  it is the domain
if [ "$n" != 0 ]; then
   echo "Domain passed in as parameter: ${DOMAIN}"
else
   echo "No domain passed in. Look for single App Server domain."
   DOMAIN="$("${SCRIPT_DIR}"/get_ps_domain.sh "${DOMAIN_DIR}")"
    RC=$?
   if [ ${RC} != 0 ]; then
        [[ ${RC} = 1 ]] && echo "Domain directory ${DOMAIN_DIR} does not exists."
        [[ ${RC} = 2 ]] && echo "Domain directory ${DOMAIN_DIR} contains either no domains or more than one domain."
        exit ${RC}
  fi
fi

# Is the DOMAIN set?
if [ "${DOMAIN}" = "" ]; then
   echo "DOMAIN not set. Stopping run."
   exit 1
fi

HOSTNAME="$(hostname)"

date
echo "---- Stopping Apps Server for domain: $DOMAIN on host: $HOSTNAME ----"

# Note the shutdown! is a forced shutdown.
"${PS_HOME}"/appserv/psadmin -c shutdown! -d "${DOMAIN}"

# Explicitly stopping rmiregistry due to a bug in PeopleTools 8.57.
# This is not needed for later versions of PeopleTools.  
# Note that there can be more than one rmiregistery process running.  All must
# be terminated when Tuxedo is shut down.

EGREP_STRING="rmiregistry"
PROCESS_COUNT=0
PID_LIST=""

echo ""
echo "Stopping rmiregistry processes..."
echo "Number of remaining process : ${PROCESS_COUNT}"
PROCESS_COUNT=$(ps -elf | grep psadm2 | grep -E  "${EGREP_STRING}" | grep -v grep | wc -l )
   if [ "${PROCESS_COUNT}" -ne 0 ]; then
        # Get the list of PIDs.
		PID_LIST=$(ps -elf | grep psadm2 | grep -E  "${EGREP_STRING}" | grep -v grep | awk '{print $4 }')
        echo "Killing processes:"
        echo "${PID_LIST}"
		# DO NOT place double quotes around PID_LIST in the following kill command to allow the pids to be separated by a space.
        kill -9 ${PID_LIST}
   fi


