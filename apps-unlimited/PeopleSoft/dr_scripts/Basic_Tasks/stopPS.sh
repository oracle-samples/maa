############################################################################
#!/bin/sh
# File name:  stopPS.sh   Version 1.0
#
# Copyright (c) 2022 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Stop the PSFT process scheduler
# 
# Usage: stopPS.sh <process scheduler domain>
#        If no parameter, look in $PS_CFG_HOME/appserv/prcs for the domain
# 
# Errors: Domain not set
#         More than one domain found.
#
# Revisions:
# Date       Who
# 7/1/2023   DPresley
############################################################################

source ~/psft.env

DOMAIN=$1
# get the length of the parameter
n=${#DOMAIN}

# Did they pass in a parameter?  it is the domain
if [ $n -!= 0 ]; then
   echo "Domain passed in as parameter: $DOMAIN"
else
  echo "No domain passed in. Look for single Process Scheduler domain."
  DOMAIN=`ls -l $PS_CFG_HOME/appserv/prcs | grep ^d | awk '{print $9}'`
  n=`echo $DOMAIN | wc -w`
  if [ $n != 1 ]; then
     echo "More than one domain directory found: $DOMAIN . Stopping run."
     echo "Count: $n"
     exit 1
  fi
fi

# Is the DOMAIN set?
if { $DOMAIN" = "" ]; then
   echo $DOMAIN not set. Stopping run."
   exit 1
fi

export $DOMAIN
export HOSTNAME=`hostname`

date
echo "-- Stopping Process Scheduler for domain: $DOMAIN on host: $HOSTNAME --"
${PS_HOME}/appserv/psadmin -p kill -d ${DOMAIN}
