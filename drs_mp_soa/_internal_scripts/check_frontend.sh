#!/bin/bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# check_frontend.sh
# Script to check if a name is resolvable, either dns or /etc/host
# Usage: check_frontend.sh <frontend_name>

#Commented this. Instead of getting the name from the config.xml, we get it as input
#frontend=`more $DOMAIN_HOME/config/config.xml | grep frontend-host`
#frontend=`echo $frontend | awk -F '<frontend-host>' '{print $2}' |awk -F '</frontend-host>' '{print $1}'`

if [[ $# -ne 1 ]]; then
        echo ""
        echo "ERROR: Incorrect number of parameters. Expected 1, got $#"
        echo "Usage:"
        echo "      $0  <frontend_name>"
        echo "Example: "
        echo "      $0 myfrontend.mycompany.com "
        echo ""
        exit 1
else
        frontend=$1
fi

echo "Checking if $frontend is resolvable.."
ping -c 1 -W 15 $frontend
result=$?
# The ping output will be 2 in case that the frontend name can't be resolved.
# We catch that case, because that is what causes soa-infra not to start.
# Not need to catch other errors as long as the name is resolved (it maybe not reachable with ping and that is not a problem)
if [[ "$result" = 2 ]]; then
        echo "Error: Frontend $frontend Name or service not known. Check the /etc/hosts in standby hosts"
        exit 1
else
        echo "OK. Frontend $frontend Name is resolvable"
fi

