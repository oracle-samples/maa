#!/usr/bin/python3

## wls_full_setup.py script version 1.0.
##
## Copyright (c) 2025 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script runs the following operations in order:
###
### 1. Data pull from primary: 
###         Retrieve WLS and OHS data from primary environment
### 2. Discovery:
###         Parse and analyze retrieved data to gather systems information automatically
### 3. OCI provisioning of resources:
###         Create and configure all required OCI resources 
### 4. Data push to OCI:
###         Push all WLS and OHS required data to OCI environment
### 5. tnsnames.ora operations:
###         5.1 - retrieval of tnsnames.ora file from primary environment
###         5.2 - update of file with OCI details
###         5.3 - push file to OCI environment
###
### NOTE:
###     i)  In order to properly run this script, the following files are expected to be properly filled in with the 
###         requested information:
###         - config/prem.env
###         - config/replication.properties
###         - the sysconfig_discovery.xlsx file saved as .csv (comma-separated values)
###
###     ii) If the server this script is run on does not have connectivity to the primary system, the optional
###         argument -n/--no-connectivity should be used (more details below). In this case, it is assumed that all the 
###         required data - WLS and OHS data as well as tnsnames.ora file - have been manually staged on the server in the 
###         proper locations and operations (1) and (5.1) will be skipped. 
### 
### This script should be executed in a bastion node with connectivity to (at least) OCI environment
### Usage:
###
###      ./wls_full_setup.py -i/--input-file INPUT_FILE [-d/--debug] [-n/--no-connectivity] [-c/--oci-config OCI_CONFIG_PATH]
###
### Where:
###     -i/--input-file INPUT_FILE:
###         INPUT_FILE is the .csv file filled in with system details - this should be the discovery variant 
###             of the sysconfig.xlsx template file
###
###     -n/--no-connectivity
###         To be used when there is no connectivity to the primary system
###         In this case, the initial data and tnsnames pull operations from primary are omitted and the data is assumed  
###             to have been manually staged in the proper locations.
###
###     -d/--debug:                
###         Print more verbose information to console
###     
###     -v/--version:
###         Show script version and exit
###
###     -c/--oci-config OCI_CONFIG_PATH:
###         To specify a path for the OCI config file if not in the default location (/home/<user>/.oci/config)
###
###
### Examples:
###     To run all operations (DATA pull -> discovery -> provisioning -> DATA push -> tnsnames pull/update/push):
###         ./wls_full_setup.py -i sysconfig_discovery.csv
###
###     Same operation as above, but in debug mode:
###         ./wls_full_setup.py -i sysconfig_discovery.csv -d 
###
###     Same operation as above, but with custom OCI config path:
###         ./wls_full_setup.py -i sysconfig_discovery.csv -d -c /path/to/oci/config
###
###     To not attempt to connect to the primary server when there is no connectivity:
###         ./wls_full_setup.py -i sysconfig_discovery.csv -n
###     NOTE: As already mentioned above, this option assumes that all required files (including tnsnames.ora) have
###             been manually staged in the proper locations. 
###
###

__version__ = "1.0"
__author__ = "mibratu"


try:
    import argparse
    import sys
    from lib.Logger import Logger
    import lib.DataReplication as DataReplication
    from lib.Utils import Constants as CONSTANTS
    import pathlib
    import datetime
    import shlex
    import subprocess
    import time
except ImportError as e:
    raise ImportError (str(e) + """
Failed to import module
Make sure all required modules are installed before running this script""")


def custom_exit(code):
    sys.exit(code)

arg_parser = argparse.ArgumentParser(description="Weblogic Hybrid DR full set-up utility")
required = arg_parser.add_argument_group("required arguments")
required.add_argument("-i", "--input-file", required=True, type=pathlib.Path,
                      help="CSV input file path with systems information")
arg_parser.add_argument("-n", "--no-connectivity", action="store_true", 
                        help="use if there is no connectivity to the primary environment")
arg_parser.add_argument("-d", "--debug", action="store_true", 
                        help="set logging to debug")
arg_parser.add_argument("-v", "--version", action='version', version=__version__)
arg_parser.add_argument("-c", "--oci-config", required=False, type=pathlib.Path, 
                      help="OCI config file path")
args = arg_parser.parse_args()
if args.debug:
    log_level = 'DEBUG'
else:
    log_level = 'INFO'
now = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M")
log_file = f"full_setup_{now}.log"
logger = Logger(__file__, log_file, log_level)
logger.writelog("info", "Starting full WLS Hybrid DR set-up")
if args.no_connectivity:
    logger.writelog("info", "No connectivity to primary environment - assuming data manually staged - running discovery")
else:
    logger.writelog("info", "Pulling data from primary environment")
    try:
        DataReplication.run(args.debug, "pull")
    except Exception as e:
        logger.writelog("error", f"Pulling data from primary environment failed: {repr(e)}")
        logger.writelog("error", "Please check specific logs for more information and help")
        custom_exit(1)
        
logger.writelog("info", "Running discovery")
cmd = f"{CONSTANTS.DISCOVERY_SCRIPT}"
if args.debug:
    cmd += " -d"
if args.no_connectivity:
    cmd += " -n"
discovery_exec = subprocess.Popen(shlex.split(cmd))
discovery_exec.wait()
if discovery_exec.returncode != 0:
    logger.writelog("error", "Discovery failed - please check specific logs for more information and help") 
    custom_exit(1)

wait_time = 15
print(f"Waiting {wait_time} seconds before continuing")
time.sleep(wait_time)

logger.writelog("info", "Provisioning OCI resources")
cmd = f"{CONSTANTS.PROVISIONING_SCRIPT} -i {args.input_file} -a"
if args.debug:
    cmd += " -d"
if args.oci_config:
    cmd += f" -c {args.oci_config}"
provision_exec = subprocess.Popen(shlex.split(cmd))
provision_exec.wait()
if provision_exec.returncode != 0:
    logger.writelog("error", "Failed during provisioning phase - please check specific logs for more information and help")
    custom_exit(0)

logger.writelog("info", "Pushing data to newly created OCI resources")
try:
    DataReplication.run(args.debug, "push")
except Exception as e:
    logger.writelog("error", f"Pushing data to secondary environment failed: {repr(e)}")
    logger.writelog("Please check specific logs for more information and help")
    custom_exit(1)

if args.no_connectivity:
    logger.writelog("info", "No connectivity to primary environment - assuming tnsnames.ora file manually staged")
else:
    logger.writelog("info", "Retrieving tnsnames.ora file from primary environment")
    try:
        DataReplication.run(args.debug, "tnsnames", pull=True)
    except Exception as e:
        logger.writelog("error", f"Pulling tnsnames.ora file from primary environment failed; {repr(e)}")
        logger.writelog("Please check specific logs for more information and help")
        custom_exit(1)

logger.writelog("info", "Updating staged tnsnames.ora file and uploading to secondary environment")
try:
    DataReplication.run(args.debug, "tnsnames", push=True)
except Exception as e:
    logger.writelog("error", f"Updating and/or uploading tnsnames.ora file failed: {repr(e)}")
    logger.writelog("Please check specific logs for more information and help")
    custom_exit(1)
logger.writelog("info", "All operations completed successfully") 