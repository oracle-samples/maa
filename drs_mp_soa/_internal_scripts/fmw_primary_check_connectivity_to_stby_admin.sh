#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

###
### This script should be executed on the WLS Admin Server Node in the Primary site
###

##### The following variables need to be passed as parameters to the script in this exact order:
##### REMOTE_ADMIN_NODE_IP         The IP of the remote node
##### REMOTE_KEYFILE               The ssh private keyfile to connect to remote node

###
### Example:
###         fmw_primary_check_connectivity_to_stby_admin.sh  '10.2.0.3'  '/path/ssh_private_keyfile'
###
export REMOTE_ADMIN_NODE_IP=$1
export REMOTE_KEYFILE=$2

echo
echo "******************************** Checking connectivity to Primary DB *******************************"
echo
# Check connectivity to remote Weblogic Administration server node and show its hostname
        echo " Checking ssh connectivity to remote Weblogic Administration server node...."
        export result=$(ssh -o ConnectTimeout=100 -o StrictHostKeyChecking=no -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} "echo 2>&1" && echo "OK" || echo "NOK" )
        if [ $result == "OK" ];then
                echo "    SUCCESS: Connectivity to ${REMOTE_ADMIN_NODE_IP} is OK"
                export REMOTE_ADMIN_HOSTNAME=$(ssh -i $REMOTE_KEYFILE opc@${REMOTE_ADMIN_NODE_IP} 'hostname --fqdn')
                echo "    REMOTE_ADMIN_HOSTNAME......" ${REMOTE_ADMIN_HOSTNAME}
                exit 0
        else
                echo "    ERROR: Failed to connect to ${REMOTE_ADMIN_NODE_IP} from primary WLS Administration node"
                exit -1
        fi


