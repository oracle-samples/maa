#!/bin/bash

## fmw_sync_in_standby.sh script version 202401
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

## This script should be executed in the SECONDARY Weblogic Administration server node.
##
### Usage:
###         ./fmw_sync_in_standby.sh DR_METHOD DOMAIN_HOME STAGE_FOLDER 
###
### Where:
###	DR_METHOD 	The DR method used in the environment (DBFS / RSYNC)
###	
##	DOMAIN_HOME     The path to the domain folder. Example: '/u01/data/domains/mydomain_domain'
##	
##	STAGE_FOLDER    The path of the folder that is used for the copy. The folder can be in DBFS or in FSS. 
##			Example: '/u01/shared/domain_copy_folder'


if [[ $# -eq 3 ]]; then
        export DR_METHOD=$1
	export DOMAIN_HOME=$2
	export STAGE_FOLDER=$3
else
	echo ""
	echo "ERROR: Incorrect value for input variable DR_METHOD passed to $0. Expected DBFS or RSYNC, got $1"
	echo "Usage: "
	echo "  $0 DR_METHOD DOMAIN_HOME STAGE_FOLDER"
	echo ""
	exit 1
fi


######################################################################################################################
############################### FUNCTIONS TO SYNC IN SECONDARY #########################################################
######################################################################################################################

sync_in_secondary(){
	export wls_domain_name=$(basename ${DOMAIN_HOME})
        echo "Rsyncing from staging folder to domain dir..."
        rm  -rf ${DOMAIN_HOME}/servers/*
        hostnm=$(hostname)
        if [[ $hostnm == *"-0"* ]]; then
                # if this is Weblogic Administration server node, copy all except tmp
                # (not valid for SOACS), because admin is wls-1 in that case
                echo "This is the Weblogic Administration server node"
                sleep 10
                rsync -avz  ${STAGE_FOLDER}/${wls_domain_name}/ ${DOMAIN_HOME}/
        else
                echo "This is not the Weblogic Administration server node"
                sleep 10
                # if this is not the Weblogic Administration server node, exclude copy servers folder also
                rsync -avz --exclude '/servers/' ${STAGE_FOLDER}/${wls_domain_name}/ ${DOMAIN_HOME}/
        fi
        echo $(date '+%Y-%m-%d-%H_%M_%S') > ${DOMAIN_HOME}/last_secondary_update.log
        echo "Rsync complete!"

}


######################################################################################################################
# END OF FUNCTIONS
######################################################################################################################
sync_in_secondary



