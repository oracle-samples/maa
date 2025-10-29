#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to install the OIG Binaries
#
echo "Installing OIG Binaries"
if [ -e <OIG_ORACLE_HOME> ]
then
    echo "OIG ALREADY INSTALLED"
else
    JAVA_HOME=<ORACLE_BASE>/jdk
    PATH=$JAVA_HOME/bin:$PATH
    if [ ! -e <ORACLE_BASE>/oraInst.loc ]
    then
       cp <WORKDIR>/oraInst.loc <ORACLE_BASE>
    fi
    java -jar <OIG_SHIPHOME_DIR>/<OIG_INSTALLER> -silent -responseFile <WORKDIR>/install_oig.rsp -invPtrLoc <ORACLE_BASE>/oraInst.loc
    if [ $? -eq 0 ]
    then
       echo "OIG SUCCESSFULLY INSTALLED"
    else
       echo "OIG FAILED"
    fi
fi
