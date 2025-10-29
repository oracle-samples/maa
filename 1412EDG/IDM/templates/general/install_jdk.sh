#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to install the JDK
#

echo "Installing Java to <ORACLE_BASE>"
TAR_FILE=$(ls <SHIPHOME_DIR>/jdk-<GEN_JDK_VER>+*_linux-x64_bin.tar.gz | head -1)

if [ -e <ORACLE_BASE>/jdk ]
then
    echo "JDK ALREADY INSTALLED"
else
    tar xvfz $TAR_FILE -C <ORACLE_BASE>
    mv <ORACLE_BASE>/jdk-<GEN_JDK_VER> <ORACLE_BASE>/jdk
    echo "JDK SUCCESSFULLY INSTALLED"
fi
