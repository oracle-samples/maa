#!/bin/sh
############################################################################
#
# File name: get_ps_domain.sh   Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: This script is called by several other scripts that will pass in domain directory locatins.
#              Returns the PS domain based on the passed in domain directory parameter.  
#              If the directory locaiotn pointed to by DOMAIN_DIR does not exists, set DOMAIN="" 
#              if the directory location pointed to by DOMAIN_DIR contains zero or 2 or more domains, set DOMAIN=""
#              if the directory location pointed to by DOMAIN_DIR contains only one domain, set DOMAIN to that domain name.
#              Return DOMAIN.
# 
# Usage: get_ps_domain.sh <domain directory locaiotnn>
# 
# Errors: Domain not set if:
#         Domain directory location does not exists.  Return exit code 1
#         More than one domain found.  Return exit code 2.
#
# Revisions:
# Date       Who         What
# 7/1/2023   DPresley    Created
############################################################################

DOMAIN_DIR="$1"
RC=0


# Check to see if DOMAIN_DIR directory exists.
   if [ -d "${DOMAIN_DIR}" ]; then
        DOMAIN=$(ls -l "${DOMAIN_DIR}" | grep ^d | grep -v prcs | awk '{print $9}')
        n=$(echo "$DOMAIN" | wc -w)
        if [ "$n" != 1 ]; then
             # There is either no domains or there are  more than one domain.  
             DOMAIN=""
			 RC=2
        fi
   else
        # Domain directory does not exists.
        DOMAIN=""
		RC=1
   fi

echo "${DOMAIN}"
# Return exit code.
exot ${RC}

