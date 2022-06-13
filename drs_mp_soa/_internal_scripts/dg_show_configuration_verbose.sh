#!/bin/bash

## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# $1 = local DB SYS password
dgmgrl sys/\'${1}\' "SHOW CONFIGURATION VERBOSE"

