#!/bin/sh

## check_soainfra.sh
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# Script that checks the soa-infra url status
# sucess exit code is returned when the status is 200 OK
# error exit code is returned when status is not 200 OK

# Customize the following variables
URL="https://soadrfrontend.example.com/soa-infra/"
USER_PASSWORD=weblogic:Password

# Fixed variables
OK_STRING="<title>Welcome to the Oracle SOA Platform on WebLogic</title>"

    # save timestamp of request
    TS=`date --rfc-3339=seconds`

    # send request
    HTTP_RESPONSE=$(curl -k --user $USER_PASSWORD --silent --write-out "HTTPSTATUS:%{http_code}" $URL)

    # extract the body
    HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')

    # extract the status
    HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    # extract the result
    RESULT=$(echo $HTTP_BODY | grep -om1 "$OK_STRING")

    # check http status
    if [ $HTTP_STATUS -eq 200  ]

    then
        if [[ "$RESULT" == $OK_STRING ]]
        then
            echo -e "$TS: $HTTP_STATUS $RESULT "
	    exit 0
        else
            echo -e "$TS: $HTTP_STATUS $RESULT "
	    exit 1
        fi
    else
        echo "$TS: Error [HTTP status: $HTTP_STATUS]"
        exit 1
    fi

