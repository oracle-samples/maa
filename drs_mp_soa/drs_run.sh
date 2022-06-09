#!/usr/bin/env bash
## DRS scripts
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

# Define python path
INTERNAL_PYTHON=./_internal_python/bin/python3

${INTERNAL_PYTHON} drs_main.py "$@"

