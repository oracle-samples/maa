#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to start Node Manager
#

echo "Starting Node Manager"
cd <NM_HOME>

nohup ./startNodeManager.sh > ./nodemanager.out 2>&1 &
