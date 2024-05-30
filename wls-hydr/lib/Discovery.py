#!/usr/bin/python3

## Discovery.py script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script analyzes Weblogic and OHS configurations to extract required information for provisioning OCI resources
### This script expects that on-prem data has been beforehand replicated on this machine using DataReplication.py script
### User will be prompted to select correct value when multiple possible values are found
### 
### Usage:
###
###      ./Discovery.py [-d/--debug]
### Where:
###      -d/--debug - print verbose output
###
### Example output:
###
### $ ./Discovery.py
### YYYY-MM-DD HH:MM:SS [INFO]: Reading configuration files
### YYYY-MM-DD HH:MM:SS [INFO]: Validating configuration file
###
### -----------------------------------------------------------------
### Select correct value for OHS HTTP port for Weblogic admin console
### 1: 7001
### 2: 8888
### 3: 8890
### -> 1
### [...]
### Discovery results:
### ------------------
###
### SQLNet ports                                         : 1521 1522
### ONS Port                                             : 6200
### Weblogic domain name                                 : domain_name
### Weblogic server ports                                : 7010 7002 8001 7001 9001 8021 8011
### Nodemanager ports                                    : 5556
### Coherence ports                                      : 9991
### Number of Weblogic nodes                             : 2
### Weblogic OS version to be used in OCI (Oracle Linux) : 7.9
### Weblogic CPU count                                   : 2
### Weblogic node memory                                 : 15
### Weblogic oracle user ID                              : 1001
### Weblogic oinstall group ID                           : 1002
### Weblogic shared config mountpoint                    : /u01/oracle/config
### Weblogic shared runtime mountpoint                   : /u01/oracle/runtime
### Weblogic products mountpoint                         : /u01/oracle/products
### Weblogic private config mountpoint                   : /u02
### Weblogic node 1 listen address                       : APPHOST1.domain.example.com
### Weblogic node 2 listen address                       : APPHOST1.domain.example.com
### Number of OHS nodes                                  : 2
### OHS OS version to be used in OCI (Oracle Linux)      : 7.9
### OHS CPU count                                        : 2
### OHS node memory                                      : 15
### OHS oracle user ID                                   : 1001
### OHS oinstall group ID                                : 1002
### OHS node 1 listen address                            : WEBHOST1
### OHS node 2 listen address                            : WEBHOST2
### OHS HTTP port for Weblogic admin console             : 7001
### OHS HTTP port                                        : 8888
### LBR virtual hostname                                 : internal.lbr.com
### LBR virtual hostname for  WebLogic Admin console     : adminconsole.lbr.com
### LBR HTTPS port                                       : 7001
### LBR port for  WebLogic Admin console                 : 8888
###
### NOTE:
### Re-run discovery script to update any of the values
### Discovery results written to file
###

__version__ = "1.0"
__author__ = "mibratu"

try:
    import xml.etree.ElementTree as ET 
    import configparser
    import datetime
    import argparse
    import paramiko
    import pathlib
    import shutil
    import glob
    import sys
    import re
    import os
    sys.path.append(os.path.abspath(f"{os.path.dirname(os.path.realpath(__file__))}"))
    from Logger import Logger
    from Utils import Utils as UTILS
    from Utils import Constants as CONSTANTS
except ImportError as e:
    raise ImportError(f"Failed to import module:\n{str(e)} \
        \nMake sure all required modules are installed before running this script")

# constants
BASEDIR = CONSTANTS.BASEDIR
EXTERNAL_CONFIG_FILE = CONSTANTS.EXTERNAL_CONFIG_FILE
INTERNAL_CONFIG_FILE = CONSTANTS.INTERNAL_CONFIG_FILE
OCI_ENV_FILE = CONSTANTS.OCI_ENV_FILE
PREM_ENV_FILE = CONSTANTS.PREM_ENV_FILE
LOG_FILE = f"{BASEDIR}/log/discovery.log"
DIRECTORIES = CONSTANTS.DIRECTORIES_CFG_TAG
PREM = CONSTANTS.PREM_CFG_TAG
RESULTS_FILE = CONSTANTS.DISCOVERY_RESULTS_FILE


def myexit(code):
    """Exit script

    Args:
        code (int): Exit code
    """
    sys.exit(code)

def add_info(prop_name, path, pretty_name, value, multiple_allowed):
    """Add info to discovery results dict

    Args:
        prop_name (str): Property name
        path (str): Path of json value to be used by OCI provisioning script. 
                    Dash separated list of parents with value as last element 
                    followed by type separated by forward slash. Example:
                        parent1-parent2-value/ip
                    Will results in:
                    {
                        'parent1':
                        {
                            'parent2': 'value'
                        }
                    }
                    And value will be validated to be a valid IP. 
                    This is handled by the OCI provisioning script
                    If path is an empty string, this element will not be added 
                    to the discovery results file.
        pretty_name (str): Pretty name to be used when printing discovery results to user.
                    If pretty_name is an empty string, this element will not be printed to user. 
        value (str|list[str]): Property value. 
        multiple_allowed (bool): If property value is a list and multiple_allowed is False, 
                    user will be prompted to select correct value. 
    """     
    discovery_sysinfo[prop_name] = {
        "p_name": pretty_name,
        "path": path,
        "value": value,
        "multiple_allowed": multiple_allowed
    }

def prompt_user_selection(options_list, prompt="Please select a value:"):
    """Prompts user to select correct value for a property from a list

    Args:
        options_list (list): List of elements to select from
        prompt (str, optional): Request prompt. Defaults to "Please select a value:".

    Returns:
        str: Selected value.
    """
    print(f"\n{'-' * len(prompt)}\n{prompt}")
    idx = 1
    for option in options_list:
        print(f"{idx}: {option}")
        idx += 1
    valid_option = False
    while not valid_option:
        opt = input("-> ")
        try:
            opt = int(opt) - 1
        except Exception:
            valid_option = False
            print("Invalid option")
            continue 
        if opt < 0 or opt >= len(options_list):
            valid_option = False
            print("invalid option")
            continue
        valid_option = True
    return options_list[opt]

def run_remote_command(ssh_wls_client, command):
    """Run a command on a remote host via paramiko

    Args:
        ssh_wls_client (paramiko.SSHClient): Paramiko SSClient object with connection to remote host
        command (str): Command to run.

    Returns:
        str: Command output
    """
    stdin, stdout, stderr = ssh_wls_client.exec_command(command)
    error = stderr.read().decode()
    if error:
        logger.writelog("error", f"Failed running command [{command}]")
        logger.writelog("error", error)
        return ""
    return stdout.read().decode().strip()

def clean_sysinfo(sysinfo):
    """Traverse discovery results dict and prompts user to select correct value where required

    Args:
        sysinfo (dict): Discovery results dict
    """
    for item in sysinfo.values():
        # if type(item['value']) == list and len(item['value']) > 1 and not item['multiple_allowed']:
        if type(item['value']) == list:
            if len(item['value']) > 1:
                if not item['multiple_allowed']:
                    item['value'] = prompt_user_selection(item['value'], f"Select correct value for {item['p_name']}")
            else:
                item['value'] = item['value'][0]

def write_results(sysinfo):
    """Write discovery results to file

    Args:
        sysinfo (dict): Discovery results dict
    """
    if os.path.isfile(RESULTS_FILE):
        now = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        shutil.copy(RESULTS_FILE, f"{RESULTS_FILE}_bkp_{now}")
    with open(RESULTS_FILE, "w") as f:
        for key, item in sysinfo.items():
            if item["path"]:
                f.write(f",,{item['path']},{','.join(item['value']) if type(item['value']) == list else item['value']}\n")



def print_discovery_results(sysinfo):
    """Print discovery results to user

    Args:
        sysinfo (dict): Discovery results dict
    """
    print("\n")
    sttl = "Discovery results:"
    print(sttl)
    print("-" * len(sttl))
    print()
    width = max([len(x['p_name']) for x in sysinfo.values()]) + 1
    for item in sysinfo.values():
        if item['p_name']:
            print(f"{item['p_name']: <{width}}: {' '.join(item['value']) if type(item['value']) == list and len(item['value']) > 1 else item['value']}")
    print("\nNOTE:")
    print("Re-run discovery script to update any of the values")
    print("Discovery results written to file")

arg_parser = argparse.ArgumentParser(description="Data replication utility")
arg_parser.add_argument("-d", "--debug", action="store_true",
                        dest="log_level",
                        help="set logging to debug")

args = arg_parser.parse_args()
log_level = 'DEBUG' if args.log_level else 'INFO'
logger = Logger(LOG_FILE, log_level)

# read configuration files
logger.writelog("info", "Reading configuration files")
# read conf files pertaining to staging locations and on-prem environment
# and update in-memory config
# fail if any file is missing
config = configparser.ConfigParser()
# this will append any common values found between configs 
for config_file in EXTERNAL_CONFIG_FILE, \
                   INTERNAL_CONFIG_FILE, \
                   PREM_ENV_FILE:
    try:
        tmp_cfg = configparser.RawConfigParser()
        with open(config_file, "r") as f:
            tmp_cfg.read_file(f)
            config = UTILS.update_config(config, tmp_cfg)
    except Exception as e:
        logger.writelog("error", f"Could not read configuration file [{config_file}]: {str(e)}")
        myexit(1)

# validate resulting configuration
# will use action set to pull and primary set to on-prem since we need to connect to prem to run several commands
logger.writelog("info", "Validating configuration file")
valid_config, errors = UTILS.validate_config(config, 'pull', primary=CONSTANTS.PREM_CFG_TAG, standby=CONSTANTS.OCI_CFG_TAG)
if not valid_config:
    logger.writelog("error", "Errors found in configuration file:")
    for error in errors:
        logger.writelog("error", error)
    myexit(1)

discovery_sysinfo = {}

## TEMPORARY HARDCODED VALUES FIRST
sqlnet_ports = ['1521', '1522']
logger.writelog("debug", f"SQLNet ports: {sqlnet_ports}")
add_info("sqlnet_ports", "oci-network-ports-sqlnet/port", "SQLNet ports", sqlnet_ports, True)

ons_port = '6200'
logger.writelog("debug", f"ONS port: {ons_port}")
add_info("ons_port", "oci-network-ports-ons/port", "ONS Port", ons_port, False)
####################################

# check that we have ssh connectivity to prem wls and ohs hosts
ohs_nodes_ips = config[PREM]['ohs_nodes'].splitlines()
wls_nodes_ips = config[PREM]['wls_nodes'].splitlines()
logger.writelog("debug", "Testing ssh connectivity to on-prem OHS node 1")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    ssh.connect(hostname=ohs_nodes_ips[0],
                username=config[PREM]['ohs_osuser'],
                key_filename=config[PREM]['ohs_ssh_key'])
except Exception as e:
    logger.writelog("error", "Cannot connect to on-prem OHS node 1")
    logger.writelog("error", str(e))
    myexit(1)
ssh.close()
logger.writelog("debug", "Testing ssh connectivity to on-prem WLS node 1")
try:
    ssh.connect(hostname=wls_nodes_ips[0],
                username=config[PREM]['wls_osuser'],
                key_filename=config[PREM]['wls_ssh_key'])
except Exception as e:
    logger.writelog("error", "Cannot connect to on-prem WLS node 1")
    logger.writelog("error", str(e))
    myexit(1)
ssh.close()

# work out wls shared config.xml path from properties files
# on-oprem path
wls_shared_cfg = config[DIRECTORIES]['WLS_CONFIG_PATH']
# staging shared dir path
wls_shared_config_path = config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR']
# replace prem path with staging path
wls_shared_cfg = wls_shared_cfg.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], wls_shared_config_path)
if not os.path.isfile(wls_shared_cfg):
    logger.writelog("error", f"WLS shared config.xml file not found [{wls_shared_cfg}]")
    myexit(1)
wls_private_config_path = config[DIRECTORIES]['STAGE_WLS_PRIVATE_CONFIG_DIR']
wls_domain_dir = pathlib.Path(wls_shared_cfg).parents[1]

domain = re.search(".*\/domains\/(.*?)\/.*", wls_shared_cfg)[1]
add_info("domain", "", "Weblogic domain name", domain, False)
# parse shared config xml file
try:
    tree = ET.parse(wls_shared_cfg)
except Exception as e:
    logger.writelog("error", f"Could not parse config file {wls_shared_cfg}")
    myexit(1)

# set up xml namespaces that we are going to need
namespaces = {
    "xmlns" : "http://xmlns.oracle.com/weblogic/domain"
}
root = tree.getroot()
# get wls server ports
wls_server_ports = [] 
wls_server_ports.extend([x.text for x in root.findall("xmlns:server/xmlns:listen-port", namespaces)])
wls_server_ports.extend([x.text for x in root.findall("xmlns:server/xmlns:ssl/xmlns:listen-port", namespaces)])
# Q: is <network-access-point> under root or under <server>?
wls_server_ports.extend([x.text for x in root.findall("xmlns:network-access-point/xmlns:listen-port", namespaces)])
wls_server_ports.append('7001')
# remove any duplicates
wls_server_ports = list(set(wls_server_ports))
logger.writelog("debug", f"WLS server ports: {wls_server_ports}")
add_info("wls_server_ports", "oci-network-ports-wlsservers/port", "Weblogic server ports", wls_server_ports, True)
# get nodemanager port (include hardcoded 5556 for now):
nm_ports = ['5556']
# get all nodemanager.properties files
nm_props_files = []
nm_props_files.extend(glob.glob(f"{wls_private_config_path}/*1*/nodemanager/nodemanager.properties"))
nm_props_files.extend(glob.glob(f"{wls_domain_dir}/nodemanager/nodemanager.properties"))
for props_file in nm_props_files:
    with open(props_file, "r") as file:
        for line in file.readlines():
            if re.search(r"^ListenPort=", line):
                nm_ports.append(line.split("=")[1].strip())
# remove duplicates
nm_ports = list(set(nm_ports))
logger.writelog("debug", f"Nodemanager ports: {nm_ports}")
add_info("nm_ports", "oci-network-ports-node_manager/port", "Nodemanager ports", nm_ports, True)

# coherence cluster ports
# get conherence config paths from config.xml
coherence_ports = []
coherence_configs = root.findall("xmlns:coherence-cluster-system-resource/xmlns:descriptor-file-name", namespaces)
# get port value from coherence config file
for config_path in coherence_configs:
    config_path =  f"{wls_domain_dir}/config/{config_path.text}"
    logger.writelog("debug", f"Checking coherence config file: {config_path}")
    with open(config_path, "r") as f:
        for line in f.readlines():
            match = re.search(r"^\s*<cluster-listen-port>(\d*)<\/cluster-listen-port>", line)
            if match:
                coherence_ports.append(match[1])
logger.writelog("debug", f"Coherence ports: {coherence_ports}")
add_info("coherence_ports", "oci-network-ports-coherence/port", "Coherence ports", coherence_ports, True)

# WLS info
# number of wls nodes
logger.writelog("debug", f"Number of WLS nodes: {len(wls_nodes_ips)}")
add_info("wls_nodes_count", "oci-wls-nodes_count/int","Number of Weblogic nodes", len(wls_nodes_ips), False)
# open ssh connection to WLS node 1 to run remote discovery commands 
wls_host = wls_nodes_ips[0]
wls_username = config[PREM]['wls_osuser']
wls_key = config[PREM]['wls_ssh_key']
ssh_wls_client = paramiko.SSHClient()
ssh_wls_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh_wls_client.connect(hostname=wls_host, username=wls_username, key_filename=wls_key)
# get os versino
wls_os_version = run_remote_command(ssh_wls_client, "grep ^VERSION= /etc/os-release")
if wls_os_version: 
    wls_os_version = wls_os_version.split('=')[1].strip('"')
    logger.writelog("debug", f"WLS OS version to be used in OCI: OL {wls_os_version}")
    add_info("wls_os_version", "oci-wls-os_version/opt", "Weblogic OS version to be used in OCI (Oracle Linux)", wls_os_version, False)
else:
    logger.writelog("warn", "Failed checking OS version on WLS node 1")
# get CPU count
wls_cpu_count = run_remote_command(ssh_wls_client, 'grep -c processor /proc/cpuinfo')
if wls_cpu_count:
    logger.writelog("debug", f"WLS CPU count to be used in OCI: {wls_cpu_count}")
    add_info("wls_cpu_count", "oci-wls-ocpu/int", "Weblogic CPU count", wls_cpu_count, False)
else:
    logger.writelog("warn", "Failed getting CPU count from wls node 1")
# get wls host memory
wls_memory = run_remote_command(ssh_wls_client, 'grep MemTotal /proc/meminfo')
if wls_memory:
    wls_memory = int(re.search(r"MemTotal:\s*(\d*)", wls_memory)[1]) // 1024 // 1024
    logger.writelog("debug", f"WLS memory to be used in OCI: {wls_memory}")
    add_info("wls_memory", "oci-wls-memory/int", "Weblogic node memory", wls_memory, False)
else:
    logger.writelog("warn", "Failed getting memory info from wls node 1")
# oracle user id
wls_oracle_uid = run_remote_command(ssh_wls_client, 'id -u')
if wls_oracle_uid:
    logger.writelog("debug", f"Weblogic {config[PREM]['wls_osuser']} user ID: {wls_oracle_uid}")
    add_info("wls_oracle_uid", "prem-wls-oracle_uid/int", f"Weblogic {config[PREM]['wls_osuser']} user ID", wls_oracle_uid, False)
else:
    logger.writelog("warn", f"Failed getting {config[PREM]['wls_osuser']} user ID from wls node 1")
# oinstall group id
wls_oinstall_gid = run_remote_command(ssh_wls_client, f"getent group {config[PREM]['wls_osgroup']} | cut -d: -f3")
if wls_oinstall_gid:
    logger.writelog("debug", f"Weblogic {config[PREM]['wls_osgroup']} group ID: {wls_oinstall_gid}")
    add_info("wls_oinstall_gid", "prem-wls-oinstall_gid/int", f"Weblogic {config[PREM]['wls_osgroup']} group ID", wls_oinstall_gid, False)
else:
    logger.writelog("warn", f"Failed getting {config[PREM]['wls_osgroup']} group ID from wls node 1")

# wls shared config mountpoint
wls_shared_config_mount = run_remote_command(ssh_wls_client, f"df --output=target {config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR']} | tail -1")
if wls_shared_config_mount:
    logger.writelog("debug", f"Weblogic shared config mountpoint: {wls_shared_config_mount}")
    add_info("wls_shared_config_mount", "prem-wls-mountpoints-config/path", f"Weblogic shared config mountpoint", wls_shared_config_mount, False)
else:
    logger.writelog("warn", f"Failed getting weblogic shared config mountpoint from wls node 1")
# wls shared runtime mountpoint
wls_shared_runtime_mount = run_remote_command(ssh_wls_client, f"df --output=target {config[DIRECTORIES]['WLS_SHARED_RUNTIME_DIR']} | tail -1")
if wls_shared_runtime_mount:
    logger.writelog("debug", f"Weblogic shared runtime mountpoint: {wls_shared_runtime_mount}")
    add_info("wls_shared_runtime_mount", "prem-wls-mountpoints-runtime/path", f"Weblogic shared runtime mountpoint", wls_shared_runtime_mount, False)
else:
    logger.writelog("warn", f"Failed getting weblogic shared runtime mountpoint from wls node 1")
# wls products mountpoint
wls_products_mountpoint = run_remote_command(ssh_wls_client, f"df --output=target {config[DIRECTORIES]['WLS_PRODUCTS']} | tail -1")
if wls_products_mountpoint:
    logger.writelog("debug", f"Weblogic products mountpoint: {wls_products_mountpoint}")
    add_info("wls_products_mountpoint", "prem-wls-mountpoints-products/path", f"Weblogic products mountpoint", wls_products_mountpoint, False)
else:
    logger.writelog("warn", f"Failed getting weblogic products mountpoint from wls node 1")
# wls private config mountpoint
wls_private_config_mount = run_remote_command(ssh_wls_client, f"df --output=target {config[DIRECTORIES]['WLS_PRIVATE_CONFIG_DIR']} | tail -1")
if wls_private_config_mount:
    logger.writelog("debug", f"Weblogic private config mountpoint: {wls_private_config_mount}")
    add_info("wls_private_config_mount", "prem-wls-mountpoints-private/path", f"Weblogic private config mountpoint", wls_private_config_mount, False)
else:
    logger.writelog("warn", f"Failed getting weblogic private config mountpoint from wls node 1")

ssh_wls_client.close()

# wls listen addresses
# first get admin server name 
adm_server_name = root.find("xmlns:admin-server-name", namespaces).text
# get all server names so we'll be able to filter out the admin server
all_server_names = [x.text for x in root.findall("xmlns:server/xmlns:name", namespaces)]
# get all listen addresses from config.xml that are not the admin server
# the loop is a workaround because the != operator in etree xpath support was added in python 3.10
# so it is not currently available in the oci version of python 
wls_listen_addresses = []
for name in all_server_names:
    if name != adm_server_name:
        wls_listen_addresses.append(root.find(f"xmlns:server/[xmlns:name='{name}']/xmlns:listen-address", namespaces).text)
# remove duplicates 
wls_listen_addresses = list(set(wls_listen_addresses))

for node_idx in range(0, len(wls_nodes_ips)):
    # connect to node
    node_ssh = paramiko.SSHClient()
    node_ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    node_ssh.connect(hostname=wls_nodes_ips[node_idx], username=wls_username, key_filename=wls_key)
    # get all IP addresses of node
    all_ips_cmd = "hostname --all-ip-addresses"
    _, node_ips, stderr = node_ssh.exec_command(all_ips_cmd)
    node_ips = node_ips.read().decode().strip()
    if not node_ips:
        logger.writelog("warn", f"Failed getting IP addresses of WLS node {node_idx} [IP: {wls_nodes_ips[node_idx]}] using command '{all_ips_cmd}'")
    else:
        node_ips = [x for x in node_ips.split(" ") if x]
    # get domain from node
    dom_cmd = "hostname --fqdn"
    _, domain, stderr = node_ssh.exec_command(dom_cmd)
    domain = domain.read().decode().strip()
    if not domain:
        logger.writelog("warn", f"Executing command '{dom_cmd}' resulted in blank output - cannot determine domain")
    else:
        domain = re.match(r".*?(\..*)$", domain)[1]
    # get IP of all listen addresses and match with node IPs
    for address in wls_listen_addresses:
        _, stdout, stderr = node_ssh.exec_command(f"getent hosts {address} | cut -d' ' -f1")
        address_ip = stdout.read().decode().strip()
        if address_ip in node_ips:
            if "." not in address:
                address += domain
            logger.writelog("debug", f"WLS node {node_idx + 1} listen address: {address}")
            add_info(f"wls_node_{node_idx + 1}_listen_address", "", f"Weblogic node {node_idx + 1} listen address", address, False)
    node_ssh.close()

# ohs info
# number of ohs nodes 
logger.writelog("debug", f"Number of OHS nodes: {len(ohs_nodes_ips)}")
add_info("ohs_nodes_count", "oci-ohs-nodes_count/int", "Number of OHS nodes", len(ohs_nodes_ips), False)
# open ssh connection to OHS node 1 to run remote discovery commands 
ohs_host = ohs_nodes_ips[0]
ohs_username = config[PREM]['ohs_osuser']
ohs_key = config[PREM]['ohs_ssh_key']
ssh_ohs_client = paramiko.SSHClient()
ssh_ohs_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh_ohs_client.connect(hostname=ohs_host, username=ohs_username, key_filename=ohs_key)
# ohs os version
ohs_os_version = run_remote_command(ssh_ohs_client, "grep ^VERSION= /etc/os-release")
if ohs_os_version: 
    ohs_os_version = ohs_os_version.split('=')[1]
    if '"' in ohs_os_version:
        ohs_os_version = ohs_os_version.strip('"')
    logger.writelog("debug", f"OHS OS version to be used in OCI: OL {ohs_os_version}")
    add_info("ohs_os_version", "oci-ohs-os_version/opt", "OHS OS version to be used in OCI (Oracle Linux)", ohs_os_version, False)
else:
    logger.writelog("warn", "Failed checking OS version on OHS node 1")
# cpu count 

ohs_cpu_count = run_remote_command(ssh_ohs_client, 'grep -c processor /proc/cpuinfo')
if ohs_cpu_count:
    logger.writelog("debug", f"OHS CPU count to be used in OCI: {ohs_cpu_count}")
    add_info("ohs_cpu_count", "oci-ohs-ocpu/int", "OHS CPU count", ohs_cpu_count, False)
else:
    logger.writelog("warn", "Failed getting CPU count from ohs node 1")
# ohs memory
ohs_memory = run_remote_command(ssh_ohs_client, 'grep MemTotal /proc/meminfo')
if ohs_memory:
    ohs_memory = int(re.search(r"MemTotal:\s*(\d*)", ohs_memory)[1]) // 1024 // 1024
    logger.writelog("debug", f"OHS memory to be used in OCI: {ohs_memory}")
    add_info("ohs_memory", "oci-ohs-memory/int", "OHS node memory", ohs_memory, False)
else:
    logger.writelog("warn", "Failed getting memory info from osh node 1")
# oracle user id
ohs_oracle_uid = run_remote_command(ssh_ohs_client, 'id -u')
if ohs_oracle_uid:
    logger.writelog("debug", f"OHS {config[PREM]['ohs_osuser']} user ID: {ohs_oracle_uid}")
    add_info("ohs_oracle_uid", "prem-ohs-oracle_uid/int", f"OHS {config[PREM]['ohs_osuser']} user ID", ohs_oracle_uid, False)
else:
    logger.writelog("warn", f"Failed getting {config[PREM]['ohs_osuser']} user ID from ohs node 1")
# oinstall group id
ohs_oinstall_gid = run_remote_command(ssh_ohs_client, f"getent group {config[PREM]['ohs_osgroup']} | cut -d: -f3")
if ohs_oinstall_gid:
    logger.writelog("debug", f"OHS {config[PREM]['ohs_osgroup']} group ID: {ohs_oinstall_gid}")
    add_info("ohs_oinstall_gid", "prem-ohs-oinstall_gid/int", f"OHS {config[PREM]['ohs_osgroup']} group ID", ohs_oinstall_gid, False)
else:
    logger.writelog("warn", f"Failed getting {config[PREM]['ohs_osgroup']} group ID from ohs node 1")
ssh_ohs_client.close()

# get list of moduleconf files
ohs_config = config[DIRECTORIES]['STAGE_OHS_PRIVATE_CONFIG_DIR']
all_module_conf_files = glob.glob(f"{ohs_config}/*/domains/*/config/fmwconfig/components/OHS/*/moduleconf/*conf")
# parse moduleconf file for various info
# get ohs listen addresses
for idx in range(1, len(ohs_nodes_ips) + 1):
    module_conf_files = glob.glob(f"{ohs_config}/*{idx}*/domains/*/config/fmwconfig/components/OHS/*/moduleconf/*conf")
    ohs_listen_address = []
    for mod_file in module_conf_files:
        with open(mod_file, "r") as file:
            for line in file.readlines():
                # ohs listen adress
                match = re.search(r"^\s*<VirtualHost\s*(.*):", line)
                if match:
                    ohs_listen_address.append(match[1])
    ohs_listen_address = list(set(ohs_listen_address))
    # remove any IP addresses
    valid_ohs_listen_address = []
    for address in ohs_listen_address:
        if UTILS.validate_ip(address):
            logger.writelog("warn", f"The IP [{address}] was found as a VirtualHost in the OHS config. Hostnames must be used instead of IPs. This OHS listen address value will be ignored.")
        else:
            valid_ohs_listen_address.append(address)
    # exit if no valid listen addresses found
    if len(valid_ohs_listen_address) == 0:
        logger.writelog("error", f"No valid listen address found for OHS node {idx} - cannot continue")
        myexit(1)
    logger.writelog("debug", f"OHS node {idx} listen addresses: {ohs_listen_address}")
    add_info(f"ohs_node_{idx}_listen_address", "", f"OHS node {idx} listen address", valid_ohs_listen_address, False)

ohs_http_ports = []
lbr_hostnames = []
lbr_ports = []
for mod_file in all_module_conf_files:
    with open(mod_file, "r") as file:
        for line in file.readlines():
            # ohs ports
            match = re.search(r"^Listen", line)
            if match:
                ohs_http_ports.append(line.split(" ")[1].strip())
            # lbr virt hostnames
            match = re.search(r"^\s*ServerName\s+(?:.*:\/\/)?(.*?)(?::|$)", line)
            if match:
                lbr_hostnames.append(match[1])
            # lbr ports
            match = re.search(r"^\s*ServerName\s+(?:.*:\/\/)?(?:.*?):(\d+)$", line)
            if match:
                lbr_ports.append(match[1])
# remove duplicates
lbr_hostnames = list(set(lbr_hostnames))
# filter out any IP's found for the LBR hostname
valid_lbr_hostnames = []
for hostname in lbr_hostnames:
    if UTILS.validate_ip(hostname):
        logger.writelog("warn", f"The IP [{hostname}] was found as a ServerName in the OHS config. Hostnames must be used instead of IPs. This value will be ignored.")
    else:
        valid_lbr_hostnames.append(hostname)
# exit if left with no valid LBR hostnames
if len(valid_lbr_hostnames) == 0:
    logger.writelog("error", f"No valid hostname found for LBR - cannot continue")
    myexit(1)
logger.writelog("debug", f"LBR virtual hostnames found: {valid_lbr_hostnames}")
add_info("lbr_virt_hostname", "oci-lbr-virtual_hostname_value/opt", "LBR virtual hostname", valid_lbr_hostnames, False)
add_info("lbr_admin_virt_hostname", "oci-lbr-admin_hostname_value/opt", "LBR admin virtual hostname for Weblogic admin console", valid_lbr_hostnames, False)

# get info from httpd.conf if not found in moduleconf files
if not ohs_http_ports:
    httpd_conf_file = glob.glob(f"{ohs_config}/*1*/domains/*/config/fmwconfig/components/OHS/*/httpd.conf")
    # regex to extract port from any of the following possible directives (as per apache docs):
    # Listen 8443
    # Listen 127.0.0.1:8443
    # Listen [2001:db8::a00:20ff:fea7:ccea]:8443
    # Listen 192.170.2.1:8443 https
    pattern = r"^\s*Listen.*?(\d*)\s*?(?:$|[a-zA-Z]*?$)"
    with open(httpd_conf_file, "r") as f:
        for line in f.readlines():
            match = re.search(pattern, line)
            if match:
                ohs_http_ports.append(match[1])
# remove any duplicates
ohs_http_ports = list(set(ohs_http_ports))
lbr_ports = list(set(lbr_ports))
logger.writelog("debug", f"OHS HTTP ports found: {ohs_http_ports}")
add_info("ohs_console_port", "oci-ohs-console_port/port", "OHS HTTP port for Weblogic admin console", ohs_http_ports, False)
add_info("ohs_http_port", "oci-ohs-http_port/port", "OHS HTTP port", ohs_http_ports, False)
logger.writelog("debug", f"LBR ports found: {lbr_ports}")
add_info("lbr_https_port", "oci-lbr-https_port/port", "LBR HTTPS port", lbr_ports, False)
add_info("lbr_admin_port", "oci-lbr-admin_port/port", "LBR port for  WebLogic Admin console", lbr_ports, False)

# add OHS products and private config paths
add_info("ohs_products", "prem-ohs-products_path/path", "", config[DIRECTORIES]['OHS_PRODUCTS'], False)
add_info("ohs_config", "prem-ohs-config_path/path", "", config[DIRECTORIES]['OHS_PRIVATE_CONFIG_DIR'], False)

# get user input on any items that require it
clean_sysinfo(discovery_sysinfo)
# present results to user
print_discovery_results(discovery_sysinfo)

# post-processing for anything that requries it:
# e.g. - listen addresses need to be an array in the csv file used 
#        as input for the oci provisioning script, not individual items
wls_addr_arr = []
for i in range(1, len(wls_nodes_ips) + 1):
    wls_addr_arr.append(discovery_sysinfo[f"wls_node_{i}_listen_address"]["value"])
add_info("wls_addr_arr", "prem-wls-listen_addresses/fqdn", "", wls_addr_arr, True)
ohs_addr_arr = []
for i in range(1, len(ohs_nodes_ips) + 1):
    ohs_addr_arr.append(discovery_sysinfo[f"ohs_node_{i}_listen_address"]["value"])
add_info("ohs_addr_arr", "prem-ohs-listen_addresses/str", "", ohs_addr_arr, True)

# write results to file
write_results(discovery_sysinfo)

