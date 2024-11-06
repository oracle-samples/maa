#!/usr/bin/python3

## cleanup.py script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script removes OCI resources stored in a sysconfig.json file.
### Resources this script can delete (and order in which it does it):
###     Compute Instances
###     Block Volumes
###     Exports
###     Mount Targets
###     File Systems
###     Load Balancers
###     Subnets
###     Route Tables
###     Security Lists
###     DHCP Options
###     NAT Gateways
###     Service Gateways
###     Internet Gateways
###     DNS Zones
###     DNS Views
###
###
### Usage:
###      ./cleanup.py -s/--sysconfig-file SYSCONFIG_FILE_PATH [-d/--debug] [-v/--version] [-c/--oci-config OCI_CONFIG_PATH] [-i/--comp-id COMPARTMENT_ID]
###
### Where:
###     -s/--sysconfig-file:
###         Path to sysconfig.json file where OCIDs of resources are stored.
###
###     -d/--debug:
###         Execute in debug mode where additional information is printed to console.
###     
###     -v/--version:
###         Show script version and exit.
###
###     -c/--oci-config:
###         Use to specify customer path location for OCI config file. If not used, default path of <user_home>/.oci/config is assumed. 
###
###     -i/--comp-id:
###         Use to manually specify the compartment OCID. The sysconfig is expected to contain this information under key:
###             sysconfig['oci']['compartment_id']
###         If the sysconfig does not contain the compartment OCID, use this option to manually specify it. 
###         Note:
###             If the sysconfig contains the compartment ID in the expected location and this option is used as well,
###             the sysconfig compartment ID will be overwritten with the one specified by this option.
###
###
### Notes:
###     Although the sysconfig.json file is expected to be one created by the wls_hydr.py script, any json file containing 
###     OCIDs for the above listed resources can be used with the following mentions:
###         1. The compartment id is expected to be found under sysconfig['oci']['compartment_id']. If it is not present 
###             in the json file, the -i/--comp-id argument must be used as explained above. 
###         2. This script will automatically extract the OCIDs regardless of the key name (nested or otherwise).
###         3. This script will only delete the resources mentioned above. Any other OCI resource type will not be modified. 
###         4. This script performs a check on the entries to determine if the resource should be deleted. This check is performed 
###             by verifying if a json entry containing an OCID also contains a key 'status'. If the 'status' key does not exist, no action will be taken.
###             Below is a list of the expected values for the 'status' key and their outcomes:
###                 - 'CREATED' - this is interpreted as being created by the wls_hydr.py script and will be deleted. 
###                 - 'PREEXISTING' - a resource that was already created prior to running the wls_hydr.py script. It will not be deleted. 
###                 - 'DELETED' - a resource that was already deleted by this script. No action will be taken. 
###                 - 'FAILED TO DELETE' - a resource that failed to be deleted by this script in the past. Re-deletion will be attempted. 
###             Examples:
###             I. Only the compute instance will be deleted:
###                 {
###                     {
###                         'status': 'CREATED',
###                         'compute_id': 'ocid1.instance.<EXAMPLE>'
###                     },
###                     {
###                         'other_compute_id': 'ocid1.instance.<EXAMPLE>'
###                     }
###                 }
###             II. As mentioned already, the script will extract all OCIDs regardless if nested or lists etc. All the following resources 
###                 will be deleted except for the load balancer (because of 'PREEXISTING' status), block volume (because of missing 'status' key)
###                 and NAT gateway(this will be skipped because of 'DELETED' status): 
###                 {
###                     "my_subnet": 
###                         {
###                             "status": "CREATED",
###                             "id": "ocid1.subnet.<EXAMPLE>"
###                             
###                         },
###                     "my_instance": 
###                         {
###                             "status": "FAILED TO DELETE",
###                             "compute_id": "ocid1.instance.<EXAMPLE>"
###                         },
###                     "my_sec_lists": 
###                         {
###                             "status": "CREATED",
###                             "sec_list_1": "ocid1.securitylist.<EXAMPLE>",
###                             "sec_list_2": "ocid1.securitylist.<EXAMPLE>"
###                         },
###                     "my_load_balancer": 
###                         {
###                             "status": "PREEXISTING",
###                             "id": "ocid1.loadbalancer.<EXAMPLE>"
###                         },
###                     "my_block_volume": 
###                         {
###                             "id": "ocid1.volume.<EXAMPLE>"
###                         },
###                     "my_nat_gateway":
###                         {
###                             'status': 'DELETED',
###                             'compute_id': 'ocid1.natgateway.<EXAMPLE>'
###                         }
###                 }
###             III. Considering the example above, if a 'status' key is common for multiple resources, it will affect all of them.
###                  None of the resources below will be deleted (because of common 'PREEXISTING' status):
###                 {
###                     "sec_lists": {
###                         "status": "PREEXISTING",
###                         "sec_list_1": "ocid1.securitylist.<EXAMPLE1>",
###                         "sec_list_2": "ocid1.securitylist.<EXAMPLE2>",
###                         "sec_list_3": "ocid1.securitylist.<EXAMPLE3>",
###                         "sec_list_4": "ocid1.securitylist.<EXAMPLE4>"
###                     }
###                 }
###

__version__ = "1.0"
__author__ = "mibratu"

try:
    import os
    import re
    import sys
    import json
    import pathlib
    import argparse
    import warnings
    from lib.Logger import Logger
    from lib.OciManager import OciManager
    from lib.Utils import Status as STATUS

except ImportError as e:
    raise ImportError (str(e) + """
Failed to import module
Make sure all required modules are installed before running this script""")

remove_order = ["instance",
                "volume",
                "export",
                "mounttarget",
                "filesystem",
                "loadbalancer",
                "subnet",
                "routetable",
                "securitylist",
                "dhcpoptions",
                "natgateway",
                "servicegateway",
                "internetgateway",
                "dns-zone",
                "dnsview"]

res_pretty_names = {
    "instance": "Compute Instance",
    "volume": "Block Volume",
    "export": "Filesystem export",
    "mounttarget": "Mount Target",
    "filesystem": "Filesystem",
    "loadbalancer": "Load Balancer",
    "subnet": "Subnet",
    "routetable": "Route Table",
    "securitylist": "Security List",
    "dhcpoptions": "DHCP options",
    "natgateway": "NAT Gateway",
    "servicegateway": "Service Gateway",
    "internetgateway": "Internet Gateway",
    "dns-zone": "DNS Zone",
    "dnsview": "DNS View"
}

def parse_sysconfig(syconfig_item, ocids_dict):
    extracted_ocids = ocids_dict
    if type(syconfig_item) not in [dict, list]:
        return extracted_ocids
    status = ""
    ocid = {}
    for value in syconfig_item.values():
        if type(value) == dict:
            parse_sysconfig(value, extracted_ocids)
        if type(value) == list:
            for item in value:
                parse_sysconfig(item, extracted_ocids)
        if 'status' in syconfig_item.keys():
            status = syconfig_item['status']
        if type(value) == str and re.match(r"ocid1\.([a-z-]*)\..*", value):
            ocid[value] = status
        extracted_ocids.update(ocid)
    return extracted_ocids

def mark_sysconfig_entry(syconfig_item, ocid_to_mark, status):
    if type(syconfig_item) not in [dict, list]:
        return 
    for value in syconfig_item.values():
        if type(value) == dict:
            mark_sysconfig_entry(value, ocid_to_mark, status)
        if type(value) == list:
            for item in value:
                mark_sysconfig_entry(item, ocid_to_mark, status)
        if value == ocid_to_mark:
            syconfig_item['status'] = status


arg_parser = argparse.ArgumentParser(description="Weblogic Hybrid DR clean-up utility")

required = arg_parser.add_argument_group("required arguments")

required.add_argument("-s", "--sysconfig-file", required=True, type=pathlib.Path, 
                      help="sysconfig json file containing the resources to be removed created by the Hybrid DR tool")
arg_parser.add_argument("-d", "--debug", action="store_true", 
                        help="set logging to debug")
arg_parser.add_argument("-v", "--version", action='version', version=__version__)
arg_parser.add_argument("-c", "--oci-config", required=False, type=pathlib.Path, 
                      help="OCI config file path")
arg_parser.add_argument("-i", "--comp-id", required=False, type=str, 
                      help="Compartment OCID")
        
args = arg_parser.parse_args()
if args.debug:
    log_level = 'DEBUG'
else:
    log_level = 'INFO'
    warnings.filterwarnings("ignore")
log_file = "cleanup.log"
logger = Logger(log_file, log_level)

sysconfig_file = args.sysconfig_file

# read sysconfig 
with open(sysconfig_file, "r") as f:
    try:
        sysconfig = json.load(f)
    except Exception as e:
        logger.writelog("error", f"sysconfig file is corrupt or not json format: {repr(e)}")
        sys.exit(1)
oci_manager_args = []

# check that the compartment OCID is where we expect it to be in the sysconfig file
try:
    compartment_id = sysconfig['oci']['compartment_id']
except NameError:
    if not args.comp_id:
        logger.writelog("error", "sysconfig json file does not contain compartment OCID in expected location")
        logger.writelog("error", "Make sure the sysconfig file is not corrupt or use '-i/--comp-id <COMPARTMENT_OCID> to manually specify the compartment OCID")
        sys.exit(1)

# even if the compartment OCID is in the sysconfig file, if the -i flag is used we overwrite it
if args.comp_id:
    compartment_id = args.comp_id
oci_manager_args.append(compartment_id)
# use cli specified oci config file if supplied
if args.oci_config:
    oci_manager_args.append(args.oci_config)
try:
    oci_manager = OciManager(*oci_manager_args)
except Exception as e:
    logger.writelog("info", "Failed to instantiate OciManager")
    logger.writelog("debug", repr(e))
    sys.exit(1)
        
resources = parse_sysconfig(sysconfig, {})

logger.writelog("info", "Extracted OCIDs and statuses:\n{0}".format("\n".join(["{0}: {1}".format(
    ocid, status) for ocid, status in resources.items() if re.match(r"ocid1.([a-z-]*).*", ocid).group(1) in remove_order]))
)

# start removing _only_ select resources in the correct order to not result in errors
removed_ocids = []
failure_encountered = False
failures = []
for type_to_remove in remove_order:
    for ocid, status in resources.items():
        res_type = ""
        res_type = re.match(r"ocid1.([a-z-]*).*", ocid).group(1)
        if res_type == type_to_remove:
            if status in [STATUS.CREATED, STATUS.FAILED_DELETE]:
                logger.writelog("info", f"Attempting to delete {res_pretty_names[res_type]} with OCID {ocid}")
                if status == STATUS.FAILED_DELETE:
                     logger.writelog("warn", "There has been at least 1 failed attempt to delete this resource in the past")
                success, log = oci_manager.delete_resource_by_type(ocid, res_type)
                if success:
                    logger.writelog("info", log)
                    removed_ocids.append(ocid)
                    mark_sysconfig_entry(sysconfig, ocid, STATUS.DELETED)
                else:
                    logger.writelog("error", log)
                    failure_encountered = True
                    failures.append(f"{res_pretty_names[res_type]}: {log} OCID: {ocid}")
                    mark_sysconfig_entry(sysconfig, ocid, STATUS.FAILED_DELETE)
            elif status == STATUS.PREEXISTING:
                logger.writelog("info", f"{res_pretty_names[res_type]} with OCID {ocid} in status {STATUS.PREEXISTING} - will not modify.")
            elif status == STATUS.DELETED:
                logger.writelog("info", f"{res_pretty_names[res_type]} with OCID {ocid} already deleted - skipping")

if failure_encountered:
    logger.writelog("error", "Failures encountered while trying to delete OCI resources:\n{0}".format("\n".join(failures)))
else:
    logger.writelog("info", "All OCI resources successfully deleted")
    
updated_resources = parse_sysconfig(sysconfig,{})
remaining_resources = []
for ocid, status in updated_resources.items():
    if status not in [STATUS.DELETED, STATUS.PREEXISTING]:
        res_short_type = re.match(r"ocid1.([a-z-]*).*", ocid).group(1)
        if res_short_type in remove_order:
            res_pretty_name = res_pretty_names[res_short_type]
            rem_line = f"{res_pretty_name} with status [{status}] and OCID [{ocid}]"
            remaining_resources.append(rem_line)

if len(remaining_resources):
    logger.writelog("warn", "Resources left after removal:\n{0}".format("\n".join(remaining_resources)))
                    

with open(sysconfig_file, "w") as f:
    json.dump(sysconfig, f)
logger.writelog("info", f"Updated sysconfig file [{sysconfig_file}]")
