#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a script to run the orapki command.
#
export JAVA_HOME=<JAVA_HOME>
export PATH=<OHS_ORACLE_HOME>/bin:$PATH
orapki $@
