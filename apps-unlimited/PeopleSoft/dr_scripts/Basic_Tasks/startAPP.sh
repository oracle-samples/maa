############################################################################
#!/bin/sh
# File name:   startAPP.sh  Version 1.0
#
# Copyright (c) 2022 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Start PeopleSoft application server on one node
# 
# Usage: startAPP.sh <app server domain>
#        If no parameter, look in $PS_CFG_HOME/appserv for the domain
# 
# Errors: Domain not set.  Could not determine domain.
#
# Revisions:
# Date       Who       What
# 7/1/2023   DPresley  Created
############################################################################

source ~/psft.env

DOMAIN=$1
# get the length of the parameter
n=${#DOMAIN}

# Did they pass in a parameter?  it is the domain
if [ $n != 0 ]; then
   echo "Domain passed in as parameter: $DOMAIN"
else
  echo "No domain passed in. Look for single App Server domain."
  DOMAIN=`ls -l $PS_CFG_HOME/appserv | grep ^d | grep -v prcs | awk '{print $9}'`
  n=`echo $DOMAIN | wc -w`
  if [ $n != 1 ]; then
     echo "More than one domain directory found: $DOMAIN . Stopping run."
     echo "Count: $n"
     exit 1
  fi
fi

# Is the domain set?
if { $DOMAIN = "" ]; then
   echo "Domain not set. Stopping run."
   exit 1
fi

export $DOMAIN
export HOSTNAME=`hostname`

date
echo "---- Starting Apps Server for domain: $DOMAIN on host: $HOSTNAME ----"
${PS_HOME}/appserv/psadmin -c boot -d $DOMAIN

