#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to install the OAM Binaries
#
echo "Installing Infrastructure Binaries"
if [ -e <OAM_ORACLE_HOME> ]
then
    echo "OAM ALREADY INSTALLED"
else
    JAVA_HOME=<ORACLE_BASE>/jdk
    PATH=$JAVA_HOME/bin:$PATH
    if [ ! -e <ORACLE_BASE>/oraInst.loc ]
    then
       cp <WORKDIR>/oraInst.loc <ORACLE_BASE>
    fi
    java -jar <OAM_SHIPHOME_DIR>/<OAM_INFRA_INSTALLER> -silent -responseFile <WORKDIR>/install_infra.rsp -invPtrLoc <ORACLE_BASE>/oraInst.loc
    if [ $? -eq 0 ]
    then
       echo "INFRASTRUCTURE SUCCESSFULLY INSTALLED"
    else
       echo "OAM FAILED"
    fi
    java -jar <OAM_SHIPHOME_DIR>/<OAM_IDM_INSTALLER> -silent -responseFile <WORKDIR>/install_oam.rsp -invPtrLoc <ORACLE_BASE>/oraInst.loc
    if [ $? -eq 0 ]
    then
       echo "OAM SUCCESSFULLY INSTALLED"
    else
       echo "OAM FAILED"
    fi
fi
