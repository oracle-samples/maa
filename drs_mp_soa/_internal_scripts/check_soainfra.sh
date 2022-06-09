#!/bin/bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# Script that checks the soa-infra url status
# success exit code is returned when the status is 200 OK
# error exit code is returned when status is not 200 OK

if [[ $# -ne 2 ]]; then
    echo
    echo "ERROR: Incorrect number of input variables passed to $0"
    echo
    echo "Usage: ${0}  soa_infra_url  wls_username:wls_password"
    echo "Example: ${0}  https://111.222.33.44/soa-infra/  weblogic:welcome1"
    echo
    exit -1
fi

# Input parameters
URL=${1}
USER_PASSWORD=${2}

# Fixed variables
#OK_STRING="<title>Welcome to the Oracle SOA Platform on WebLogic</title>"
OK_STRING=

    # save timestamp of request
    TS=$(date --rfc-3339=seconds)

    # send request
    HTTP_RESPONSE=$(curl --user ${USER_PASSWORD} --insecure --write-out "HTTPSTATUS:%{http_code}" ${URL})

    # extract the body
    HTTP_BODY=$(echo ${HTTP_RESPONSE} | sed -e 's/HTTPSTATUS\:.*//g')

    # extract the status
    HTTP_STATUS=$(echo ${HTTP_RESPONSE} | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # extract the result
    RESULT=$(echo ${HTTP_BODY} | grep -om1 "${OK_STRING}")

    # check http status
    if [[ ${HTTP_STATUS} -eq 200  ]]; then
        echo -e "${TS}: ${HTTP_STATUS} ${RESULT} "
        exit 0
        #if [[ "$RESULT" == ${OK_STRING} ]]; then
        #    echo -e "${TS}: ${HTTP_STATUS} ${RESULT} "
	      #  exit 0
        #else
        #    echo -e "${TS}: ${HTTP_STATUS} ${RESULT} "
	      #  exit 1
        #fi
    else
        echo "${TS}: Error [HTTP status: ${HTTP_STATUS}]"
        exit 1
    fi
