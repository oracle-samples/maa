#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

MS_NAME=""

for i in "$@"
do
case $i in
    --managed=*)
    MS_NAME="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done


if [ ${MS_NAME} eq "" ]
then
    echo "ERROR: No managed server name provided"
    echo
    echo "Usage:  $0 --managed soasrv_server_1"
    exit -1

fi


RET="NO_ERROR"

echo
echo "Checking if WLS stack components are running on this host [`hostname`]"

echo
echo "  1) Checking if Node Manager is running"
NM_PID=$(pgrep -f '\-Dweblogic.nodemanager.JavaHome.*weblogic.NodeManager')
if [ ! -z "${NM_PID}" ]
then
    echo "    Node Manager is running. PID=${NM_PID}"
else
    echo "ERROR: Could not find a Node Manager Server on this host"
    RET="ERROR"
fi

echo "  2) Checking if Admin Server is running"
AS_PID=$(pgrep -f '\-Dweblogic.Name=.*adminserver')
if [ ! -z "${AS_PID}" ]
then
    echo "    Admin Server is running. PID=${AS_PID}"
else
    echo "ERROR: Could not find an Admin Server on this host"
    RET="ERROR"
fi

echo "  3) Checking if Managed Server [${MS_NAME}] is running"
MS_PID=$(pgrep -f '\-Dweblogic.Name=.*${MS_NAME}')
if [ ! -z "${MS_PID}" ]
then
    echo "    Managed Server is running. PID=${MS_PID}"
else
    echo "ERROR: Could not find an Managed Server on this host"
    RET="ERROR"
fi

if [ ${RET} eq "ERROR" ]
    exit -1
else
    exit 0

