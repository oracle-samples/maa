#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to run opatch
#
export ORACLE_HOME=<ORACLE_HOME>
export JAVA_HOME=<JAVA_HOME>
export PATH=$JAVA_HOME/bin:$ORACLE_HOME/OPatch:$PATH

patchDir=$1
cd /tmp/$patchDir
opatch apply -silent 

exit $?
