#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
# $1 = primary DB SYS password
# $2 = primary DB unique name
# $3 = standby DB unique name
dgmgrl sys/\'${1}\'@${2} "SWITCHOVER TO \"${3}\""


