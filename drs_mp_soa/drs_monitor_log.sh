#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
tail -f ${1} | grep --line-buffered -v ' \[DEBUG\]' | grep --line-buffered -v 'paramiko' | egrep --line-buffered -E "(^####|drs_)"
