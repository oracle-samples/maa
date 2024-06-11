############################################################################
#!/bin/sh
# File name:  stopWS.sh    Version 1.0
#
# Copyright (c) 2022 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Stop the PeopleSoft PIA / WLS server
# 
# Usage:     stopWS.sh <domain>
# 
# Errors:    No domain passed in, more than one found
#
# Revisions:
#
# Date       Who        What
# 7/1/2023   DPresley   Created
############################################################################

source ~/psft.env

DOMAIN=$1
# get the length of the parameter
n=${#DOMAIN}

# Did they pass in a parameter?  it is the domain
if [ $n != 0 ]; then
   echo "Domain passed in as parameter: $DOMAIN"
else
  echo "No domain passed in. Look for single WLS Server domain."
  DOMAIN=`ls -l $PS_CFG_HOME/webserv | grep ^d | awk '{print $9}'`
  n=`echo $DOMAIN | wc -w`
  if [ $n != 1 ]; then
     echo "More than one domain directory found: $DOMAIN . Stopping run."
     echo "Count: $n"
     exit 1
  fi
fi

# Is the domain set?
if { $DOMAIN = "" }; then
   echo "Domain not set. Stopping run."
   exit 1
fi

export $DOMAIN
export HOSTNAME=`hostname`

date
echo "------ Stopping WLS Server for domain: $domain on host: $HOSTNAME ----"
${PS_CFG_HOME}/webserv/${DOMAIN}/bin/stopPIA.sh
