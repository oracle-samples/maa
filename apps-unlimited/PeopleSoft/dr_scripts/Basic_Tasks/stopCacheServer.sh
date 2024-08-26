#!/bin/bash
############################################################################
#
# File name: stopCacheServer.sh  Version 1.0
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description: Stop Coherence*Web cache server
# 
# Usage: stopCacheServer.sh
#        NOTE: THIS STOPS ALL COHERENCE PROCESSES RUNNING ON THIS SERVER
# 
# Errors: None
#
############################################################################
  
EGREP_STRING="coherence"
PROCESS_COUNT=0
PID_LIST=""

    echo "Stopping Coherence*Web Cache Server..."
    PROCESS_COUNT=$(ps -elf | grep psadm2 | grep -E "${EGREP_STRING}" | grep -v grep | wc -l )
    echo "Number of remaining process : ${PROCESS_COUNT}"

     if [ "${PROCESS_COUNT}" -ne 0 ]; then
          PID_LIST=$(ps -elf | grep psadm2 | grep -E "${EGREP_STRING}" | grep -v grep | awk '{ print $4 }' )
          echo "Killing processes: "
          echo "${PID_LIST}"
		  # DO NOT place double quotes around ${PID_LIST} as this will remove spaces between pids and cause the kill command to fail.
          kill -9 ${PID_LIST}
     fi


