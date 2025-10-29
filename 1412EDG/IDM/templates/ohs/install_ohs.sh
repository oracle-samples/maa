#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to install the OHS Binaries
#
echo "Installing OHS Binaries"
if [ -e <OHS_ORACLE_HOME> ]
then
    echo "OHS ALREADY INSTALLED"
else
    JAVA_HOME=<ORACLE_BASE>/jdk
    PATH=$JAVA_HOME/bin:$PATH
    if [ ! -e <ORACLE_BASE>/oraInst.loc ]
    then
       cp <WORKDIR>/oraInst.loc <ORACLE_BASE>
    fi
    <OHS_SHIPHOME_DIR>/<OHS_INSTALLER> -silent -responseFile <WORKDIR>/install_ohs.rsp -invPtrLoc <ORACLE_BASE>/oraInst.loc
    ln -s $JAVA_HOME <OHS_ORACLE_HOME>
    if [ $? -eq 0 ]
    then
       echo "OHS SUCCESSFULLY INSTALLED"
    else
       echo "OHS FAILED"
    fi
fi
