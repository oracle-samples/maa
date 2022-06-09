#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

#
# Script checks 'ps' output to find process with the specified name
#   Script prints:
#       "SUCCESS": if process found
#       "FAILURE": if process was not found
#
# Usage:  ${0} "search_string"
#   where:  search_string -- some part of the name of the process name to search in 'ps -ef' output
#

# Get the last argument (the search string)
for i in $@; do :; done
SEARCH_STRING="$i"

if [[ ! ${SEARCH_STRING} ]]
then
    echo "ERROR: You must provide a search string as argument"
    exit 1
fi

echo
echo "Checking for process matching [${SEARCH_STRING}] in ps output on this host [`hostname`]"
echo

PROC_COUNT=$(/usr/bin/pgrep -f ${SEARCH_STRING} | wc -l)

if [[ ${PROC_COUNT} == 3 ]]
then
    echo "SUCCESS: Process containing [${SEARCH_STRING}] is running."
else
    echo "FAILURE: Could not find process containing string [${SEARCH_STRING}] on this host"
fi
