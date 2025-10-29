#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to install the OUD Binaries
#

echo "Installing OUD Binaries"
if [ -e <OUD_ORACLE_HOME>/oud ]
then
    echo "OUD ALREADY INSTALLED"
else
    JAVA_HOME=<ORACLE_BASE>/jdk
    PATH=$JAVA_HOME/bin:$PATH
    if [ ! -e <ORACLE_BASE>/oraInst.loc ]
    then
       cp <WORKDIR>/oraInst.loc <ORACLE_BASE>
    fi
    java -jar <OUD_SHIPHOME_DIR>/<OUD_INSTALLER> -silent -responseFile <WORKDIR>/install_oud.rsp -invPtrLoc <ORACLE_BASE>/oraInst.loc
    if [ $? -eq 0 ]
    then
       echo "OUD SUCCESSFULLY INSTALLED"
    else
       echo "OUD FAILED"
    fi
fi
