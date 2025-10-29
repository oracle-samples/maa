#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to install the OUDSM Binaries
#
echo "Installing Infrastructure Binaries"
if [ -e <OUDSM_ORACLE_HOME> ]
then
    echo "OUDSM ALREADY INSTALLED"
else
    JAVA_HOME=<ORACLE_BASE>/jdk
    PATH=/bin:$PATH
    java -jar <OUDSM_SHIPHOME_DIR>/<OUDSM_INFRA_INSTALLER> -silent -responseFile <WORKDIR>/install_infra.rsp -invPtrLoc <WORKDIR>/oraInst.loc
    if [ $? -eq 0 ]
    then
       echo "INFRASTRUCTURE SUCCESSFULLY INSTALLED"
    else
       echo "OUDSM FAILED"
    fi
    java -jar <OUDSM_SHIPHOME_DIR>/<OUDSM_INSTALLER> -silent -responseFile <WORKDIR>/install_oudsm.rsp -invPtrLoc <WORKDIR>/oraInst.loc
    if [ $? -eq 0 ]
    then
       echo "OUDSM SUCCESSFULLY INSTALLED"
    else
       echo "OUDSM FAILED"
    fi
fi
