#!/usr/bin/python3 

__version__ = "1.0"
__author__ = "mibratu"

try:
    import os
    import re
    import json
    import argparse
    import datetime
    import pathlib
    import csv
    import sys
    import traceback
    from lib.Logger import Logger
    from lib.OciManager import OciManager
    from lib.Utils import Utils
    from lib.Utils import Constants as CONSTANTS
    import configparser
    import requests
    import paramiko
    import time

except ImportError as e:
    raise ImportError (str(e) + """
Failed to import module
Make sure all required modules are installed before running this script""")

arg_parser = argparse.ArgumentParser(description="Weblogic Hybrid DR set-up utility")

required = arg_parser.add_argument_group("required arguments")

required.add_argument("-i", "--input-file", required=True, type=pathlib.Path, 
                      help="CSV input file path with systems information")

arg_parser.add_argument("-a", "--auto-discovery", action="store_true", 
                        help="use Discovery.py results")
arg_parser.add_argument("-d", "--debug", action="store_true", 
                        help="set logging to debug")
arg_parser.add_argument("-v", "--version", action='version', version=__version__)
arg_parser.add_argument("-c", "--oci-config", required=False, type=pathlib.Path, 
                      help="OCI config file path")

args = arg_parser.parse_args()

log_level = 'DEBUG' if args.debug else 'INFO'
log_file = "wls_hydr.log"
logger = Logger(log_file, log_level)
basedir = os.path.dirname(os.path.realpath(__file__))
sysconfig = {}

DHCP_OPT_NAME = "HyDR-DHCP"
PRIVATE_VIEW_NAME = "HYBRID_DR_VIRTUAL_HOSTNAMES"
WLS_INIT_SCRIPT = f"{basedir}/lib/templates/wls_node_init.sh"
OHS_INIT_SCRIPT = f"{basedir}/lib/templates/ohs_node_init.sh"
LBR_ADMIN_BACKEND_SET_NAME = "OHS_Admin_backendset"
LBR_ADMIN_COOKIE_NAME = "X-Oracle-LBR-ADMIN-Backendset"
LBR_HTTP_BACKEND_SET_NAME = "OHS_HTTP_APP_backendset"
LBR_HTTP_COOKIE_NAME = "X-Oracle-LBR-OHS-HTTP-Backendset"
LBR_INTERNAL_BACKEND_SET_NAME = "OHS_HTTP_INTERNAL_backendset"
LBR_INTERNAL_COOKIE_NAME = "X-Oracle-LBR-OHS-Internal-Backendset"
LBR_EMPTY_BACKEND_SET_NAME = "empty_backendset"
LBR_CERT_NAME = "HyDR_lbr_cert"
LBR_HOSTNAME_NAME = "HyDR_LBR_virtual_hostname"
LBR_ADMIN_HOSTNAME_NAME = "HyDR_LBR_admin_hostname"
LBR_VIRT_HOST_HOSTNAME_NAME = "internal_frontend"
LBR_ADMIN_LISTENER = "Admin_listener"
LBR_HTTPS_LISTENER = "HTTPS_APP_listener"
LBR_HTTP_LISTENER = "HTTP_APP_listener"
LBR_VIRT_HOST_LISTENER = "HTTP_internal_listener"
LBR_SSLHEADERS_RULE_SET = "SSLHeaders"
LBR_HTTP_REDIRECT_RULE_SET = "HTTP_to_HTTPS_redirect"
LBR_HTTP_PORT = 80
DISCOVERY_RESULTS = CONSTANTS.DISCOVERY_RESULTS_FILE

def save_sysconfig(config, file):
    with open(file, "w") as f: 
        json.dump(config, f)
        f.truncate()

def build_json(path, value, config):
    """Function that builds a config dict based on the following input

    Args:
        path (str): hyphen delimited json keys path
        value (str): value to be added to the last key in path
        config (dict): existing dict to build/append
    """
    path = path.split("-")
    tmp_config = config
    for node in path:
        if node not in tmp_config.keys():
            tmp_config[node] = {}
        if node != path[-1]:
            tmp_config = tmp_config[node]
        else:
            tmp_config[node] = value

def sanitize_input_file(file_path, fail=False):
    """Function to remove any non unicode characters from a file

    Args:
        file_path (_type_): Path to file to check
        fail (bool, optional): Fail flag used internally when recursively calling itself. 
                                Should not be used when calling function. If file still contains 
                                non unicode characters after a sanitation attempt, function exits script.
    """
    sanitize = False
    with open(file_path, "r") as f:
        try: 
            _ = f.read()
        except UnicodeDecodeError:
            if fail:
                logger.writelog("error", f"Input file [{file_path}] still contains illegal characters")
                logger.writelog("error", "Cannot continue - exiting")
                sys.exit(1)
            sanitize = True
    if not sanitize:
        if fail:
            logger.writelog("info", "Input file sanitized and can be parsed")
        return 
    
    logger.writelog("warn", "Input file contains illegal characters - attempting to sanitize")
    clean_data = ""
    with open(file_path, "rb") as f:
        for line in f.readlines():
            clean_data += line.decode('utf-8', 'ignore')
    with open(file_path, "w") as f:
        f.write(clean_data)
    sanitize_input_file(file_path, fail=True)
            
def parse_input_file(file_path):
    """Function that parses a csv file 

    Args:
        file_path (str): path to csv file
    """
    logger.writelog("debug", f"File: {file_path}")
    if not os.path.isfile(file_path):
        logger.writelog("error", "File does not exist - exiting")
        sys.exit(1)
    else:
        logger.writelog("info", "File found - continuing")
    sanitize_input_file(file_path)
    csv_data = []
    logger.writelog("info", "Reading csv data")
    with open(file_path, "r") as f:
        try:
            dialect = csv.Sniffer().sniff(f.readline())
            f.seek(0)
            data = csv.reader(f, dialect)
            for row in data:
                if "END" in row[0]:
                    break
                if row[0].startswith("#"):
                    continue
                csv_data += [row]
        except csv.Error as e:
            logger.writelog("error", f"Csv file could not be parsed.")
            logger.writelog("error", "Make sure to save file as 'CSV (Comma delimited) (*.csv)'")
            logger.writelog("debug", f"Csv module error: {str(e)}")
            sys.exit(1)
    logger.writelog("info", "Csv data read - validating")
    data_valid = True
    validation_errors = []
    for row in csv_data:
        try:
            json_path, type = row[3].split("/")
            value = [val.strip() for val in row[4:] if val.strip() != ""]
            if len(value) == 0:
                value = ""
            elif len(value) == 1:
                value = value[0]
            if isinstance(value, list):
                for val in value:
                    if not Utils.validate_by_type(type, val):
                        data_valid = False
                        validation_errors.append(f"Invalid value [{val}] for [{json_path}]")
            else:
                if not Utils.validate_by_type(type, value):
                    data_valid = False
                    validation_errors.append(f"Invalid value [{value}] for [{json_path}]")
            build_json(json_path, value, sysconfig)
        except Exception as e:
            logger.writelog("error", "Invalid csv file - data missing or altered")
            logger.writelog("error", "Make sure to save file as 'CSV (Comma delimited) (*.csv)'")
            logger.writelog("debug", f"Exception encountered: {repr(e)}")
            if args.debug:
                traceback.print_exc()
            sys.exit(1)

    if not data_valid:
        logger.writelog("error", "Invalid data found in csv file, see below:")
        for error in validation_errors:
            logger.writelog("error", error)
        logger.writelog("error", "Correct errros and try again with new template file")
        sys.exit(1)

    logger.writelog("info", "Csv data validated - building sysconfig json")

def main():
    logger.writelog("info", "Parsing input CSV file")
    parse_input_file(args.input_file)
    if args.auto_discovery:
        logger.writelog("info", "Auto discovery selected - parsing discovery results")
        parse_input_file(DISCOVERY_RESULTS)
    # make sure keys specified in template file exist
    if os.path.isfile(sysconfig['oci']['ssh_public_key']):
        if not os.access(sysconfig['oci']['ssh_public_key'], os.R_OK):
            logger.writelog("error", "Public key file {0} exists but cannot be read - fix permissions and try again".format(
                sysconfig['oci']['ssh_public_key'])
            )
            sys.exit(1)
    else:
        logger.writelog("error", f"Public key file {sysconfig['oci']['ssh_public_key']} does not exist")
        sys.exit(1)
    # build the wls nodes, products fs, and block volumes arrays
    sysconfig['oci']['wls']['nodes'] = []
    sysconfig['oci']['storage']['fss']['products'] = []
    sysconfig['oci']['storage']['block_volumes'] = []
    for count in range(0, int(sysconfig['oci']['wls']['nodes_count'])):
        # nodes
        sysconfig['oci']['wls']['nodes'].append(
            {
                "name" : f"{sysconfig['oci']['wls']['node_prefix']}{count + 1}"
            })
        # block volumes
        sysconfig['oci']['storage']['block_volumes'].append(
            {
                "name" : f"wlsdrBV{count + 1}"
            })
        
    # 2 products filesystems
    for suffix in [1, 2]:
        sysconfig['oci']['storage']['fss']['products'].append(
            {
                "name" : f"{sysconfig['oci']['storage']['fss']['products_prefix_name']}{suffix}", 
                "export_path" : f"{sysconfig['oci']['storage']['fss']['products_export_prefix']}{suffix}"
            })
    # build the ohs nodes array    
    sysconfig['oci']['ohs']['nodes'] = []
    for count in range(0, int(sysconfig['oci']['ohs']['nodes_count'])):
        sysconfig['oci']['ohs']['nodes'].append(
            {
                "name" : f"{sysconfig['oci']['ohs']['node_prefix']}{count + 1}"
            })
    # get domain from wls fqdn listen addresses
    sysconfig['prem']['network']['fqdn'] = re.match(r".*?\.(.*)", sysconfig['prem']['wls']['listen_addresses'][0])[1]
    # strip domain from listen addresses - expected format for creating private views
    for idx in range(0, len(sysconfig['prem']['wls']['listen_addresses'])):
        sysconfig['prem']['wls']['listen_addresses'][idx] = re.match(r"(.*?)\..*", sysconfig['prem']['wls']['listen_addresses'][idx])[1]
    # get bastion server information if in OCI
    if sysconfig['bastion']['location'] == 'oci':
        req = requests.get("http://169.254.169.254/opc/v1/vnics/")
        data = req.json()[0]
        sysconfig['bastion']['private_ip'] = data['privateIp']
    oci_manager_args = []
    oci_manager_args.append(sysconfig['oci']['compartment_id'])
    # use cli specified oci config file if supplied
    if args.oci_config:
        oci_manager_args.append(args.oci_config)
    try:
        oci_manager = OciManager(*oci_manager_args)
    except Exception as e:
        logger.writelog("info", "Failed to instantiate OciManager")
        logger.writelog("debug", repr(e))
        sys.exit(1)
    # get availability domains
    success, ret = oci_manager.get_availability_domains()
    if not success:
        logger.writelog("error", "Could not query OCI for availability domains")
        logger.writelog("debug", ret)
        sys.exit(1)
    # check if there are 2 ADs if round robin selected
    if sysconfig['oci']['round_robin'] == "Yes":
        if len(ret) < 2:
            logger.writelog("warning", "Round-robin set to yes, but only 1 availability domain available - reverting to no")
            sysconfig['oci']['round_robin'] = "No"
            sysconfig['oci']['availability_domains'] = [ret[0]]
        else:
            # use only 2 ADs if round robin selected and multiple ADs available
            logger.writelog("info", f"Round robin set to yes, will use the following ADs when creating resources: {ret[0]}, {ret[1]}")
            sysconfig['oci']['availability_domains'] = ret[0:2]
    else:
        sysconfig['oci']['availability_domains'] = [ret[0]]

    # create mounttargets entries in sysconfig based on round robin
    sysconfig['oci']['storage']['fss']['mounttargets']['targets'] = []
    if sysconfig['oci']['round_robin'] == "Yes":
        # use a for loop in case we want to extend the number of ADs used in the future
        for count in range(0, min(len(sysconfig['oci']['wls']['nodes']), len(sysconfig['oci']['availability_domains']))):
            sysconfig['oci']['storage']['fss']['mounttargets']['targets'].append({"name" : f"{sysconfig['oci']['storage']['fss']['mounttargets']['prefix']}{count + 1}"})
    else:
        # use just one AD if not round robin
        sysconfig['oci']['storage']['fss']['mounttargets']['targets'].append({"name" : f"{sysconfig['oci']['storage']['fss']['mounttargets']['prefix']}1"})

    logger.writelog("debug", "The following config has been extracted from " 
                    + f"the csv file:\n{json.dumps(sysconfig, indent=4)}")

    now = datetime.datetime.now().strftime("%Y-%m-%d_%H:%M")
    sysconfig_file = f"{basedir}/config/sysconfig_{now}.json"
    logger.writelog("debug", f"Saving sysconfig to {sysconfig_file}")
    save_sysconfig(sysconfig, sysconfig_file)


    # check if VCN needs to be created - create if yes/retrieve vcn data if no
    if sysconfig['oci']['network']['vcn']['create'] == "Yes":
        logger.writelog("info", f"Creating VCN [{sysconfig['oci']['network']['vcn']['name']}]")
        # check if there already exists a vcn in the given compartment with the same name
        success, ret = oci_manager.get_vcn_by_name(sysconfig['oci']['network']['vcn']['name'])
        if not success:
            logger.writelog("error", f"Could not check OCI if VCN {sysconfig['oci']['network']['vcn']['name']} already exists")
            logger.writelog("debug", ret)
            sys.exit(1)
        if ret is not None:
            logger.writelog("error", f"A VCN with the name [{sysconfig['oci']['network']['vcn']['name']}] already exists")
            sys.exit(1)
        if isinstance(sysconfig['oci']['network']['vcn']['cidr'], list):
            success, ret = oci_manager.create_vcn(
                sysconfig['oci']['network']['vcn']['name'],
                sysconfig['oci']['network']['vcn']['cidr']
            )
        else:
            success, ret = oci_manager.create_vcn(
                sysconfig['oci']['network']['vcn']['name'],
                [sysconfig['oci']['network']['vcn']['cidr']]
            )
        if not success:
            logger.writelog("error", "Could not create VCN")
            logger.writelog("debug", ret)
            sys.exit(1)
    else:
        logger.writelog("info", f"Retrieving information for VCN [{sysconfig['oci']['network']['vcn']['name']}]")
        success, ret = oci_manager.get_vcn_by_name(sysconfig['oci']['network']['vcn']['name'])
        if not success:
            logger.writelog("error", f"Could not Query OCI for VCN [{sysconfig['oci']['network']['vcn']['name']}]")
            logger.writelog("debug", ret)
            sys.exit(1)
        if ret is None:
            logger.writelog("error", f"No VCN named [{sysconfig['oci']['network']['vcn']['name']}] found in given compartment")
            sys.exit(1)

    # save required vcn details in sysconfig
    sysconfig['oci']['network']['vcn']['id'] = ret.id
    sysconfig['oci']['network']['vcn']['default_route_table_id'] = ret.default_route_table_id
    sysconfig['oci']['network']['vcn']['security_list_id'] = ret.default_security_list_id
    sysconfig['oci']['network']['vcn']['status'] = "COMPLETED"
    save_sysconfig(sysconfig, sysconfig_file)

    # create internet gateway: if vcn already exists check first if internet gateway also exists and retrieve info
    CREATE_IG = True
    if sysconfig['oci']['network']['vcn']['create'] == "No":
        logger.writelog("info", "Checking if Internet Gateway exists")
        success, ret = oci_manager.get_internet_gateway(vcn_id=sysconfig['oci']['network']['vcn']['id'])
        if not success:
            logger.writelog("error", "Failed querying OCI for Internet Gateway")
            logger.writelog("debug", ret)
            sys.exit(1)
        if ret is not None:
            CREATE_IG = False
            logger.writelog("info", "Internet Gateway found - retrieved info")
        else:
            logger.writelog("info", "No Internet Gateway found - creating")
    else:
        logger.writelog("info", "Creating Internet Gateway")

    if CREATE_IG:
        success, ret = oci_manager.create_internet_gateway(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            internet_gateway_name="HyDR_Internet_Gateway"
        )
        if not success:
            logger.writelog("error", "Failed creating Internet Gateway")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created Internet Gateway")
    sysconfig['oci']['network']['internet_gateway']['id'] = ret.id
    sysconfig['oci']['network']['internet_gateway']['name'] = ret.display_name
    save_sysconfig(sysconfig, sysconfig_file)


    # add internet gateway to default route table if requested in template file
    ADD_IG = False
    if sysconfig['oci']['network']['internet_gateway']['add'] == "Yes":
        ADD_IG = True
        logger.writelog("info", "Adding Internet Gateway to VCN default route table")
        # first check if internet gateway already added to default route table if VCN already exists
        if sysconfig['oci']['network']['vcn']['create'] == "No":
            success, ret = oci_manager.get_route_table(
                route_table_id=sysconfig['oci']['network']['vcn']['default_route_table_id']
            )
            if not success:
                logger.writelog("error", "Could not query OCI for VCN default route rules")
                logger.writelog("debug", ret)
                sys.exit(1)
            for rule in ret.route_rules:
                if rule.network_entity_id == sysconfig['oci']['network']['internet_gateway']['id']:
                    logger.writelog("info", "Internet Gateway already added to VCN default route table")
                    ADD_IG = False
                    break

    if ADD_IG:
        success, ret = oci_manager.add_ig_to_route_table(
            sysconfig['oci']['network']['vcn']['default_route_table_id'],
            sysconfig['oci']['network']['internet_gateway']['id']
        )
        if not success:
            logger.writelog("error", "Failed adding Internet Gateway to default route table")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully added Internet Gateway to VCN default route table")

    # create service gateway: if vcn already exists check first if service gateway also exists and retrieve info
    sysconfig['oci']['network']['service_gateway'] = {}
    CREATE_SG = True
    if sysconfig['oci']['network']['vcn']['create'] == "No":
        logger.writelog("info", "Checking if Service Gateway exists")
        success, ret = oci_manager.get_service_gateway(
            vcn_id=sysconfig['oci']['network']['vcn']['id']
        )
        if not success:
            logger.writelog("error", "Could not query OCI for Service Gateway")
            logger.writelog("debug", ret)
        if ret is not None:
            CREATE_SG = False
            logger.writelog("info", "Service Gateway found - retrieved info")
        else:
            logger.writelog("info", "No Service Gateway found - creating")
    else:
        logger.writelog("info", "Creating Service Gateway")

    if CREATE_SG:
        success, ret = oci_manager.create_service_gateway(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            service_gw_name="HyDR_Service_Gateway"
        )
        if not success:
            logger.writelog("error", "Failed creating Service Gateway")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created Service Gateway")
    sysconfig['oci']['network']['service_gateway']['id'] = ret.id
    sysconfig['oci']['network']['service_gateway']['name'] = ret.display_name
    service_id = ret.services[0].service_id
    # get OSN cidr of Service Gateway
    success, ret = oci_manager.get_osn_details(service_id)
    if not success:
        logger.writelog("error", "Could not query OCI for OSN service details")
        logger.writelog("debug", ret)
        sys.exit(1)
    sysconfig['oci']['network']['service_gateway']['cidr'] = ret.cidr_block
    save_sysconfig(sysconfig, sysconfig_file)

    # create NAT gateway: if vcn already exists check first if NAT gateway also exists and retrieve info
    sysconfig['oci']['network']['nat_gateway'] = {}
    CREATE_NAT = True
    if sysconfig['oci']['network']['vcn']['create'] == "No":
        logger.writelog("info", "Checking if NAT Gateway exists")
        success, ret = oci_manager.get_nat_gateway(
            vcn_id=sysconfig['oci']['network']['vcn']['id']
        )
        if not success:
            logger.writelog("error", "Could not query OCI for NAT Gateway")
            logger.writelog("debug", ret)
        if ret is not None:
            CREATE_NAT = False
            logger.writelog("info", "NAT Gateway found - retrieved info")
        else:
            logger.writelog("info", "No NAT Gateway found - creating")
    else:
        logger.writelog("info", "Creating NAT Gateway")

    if CREATE_NAT:
        success, ret = oci_manager.create_nat_gateway(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            nat_gw_name="HyDR_NAT_Gateway"
        )
        if not success:
            logger.writelog("error", "Failed creating NAT Gateway")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created NAT Gateway")
    sysconfig['oci']['network']['nat_gateway']['id'] = ret.id
    sysconfig['oci']['network']['nat_gateway']['name'] = ret.display_name
    sysconfig['oci']['network']['nat_gateway']['ip'] = ret.nat_ip
    save_sysconfig(sysconfig, sysconfig_file)

    # create private subnets route table
    logger.writelog("info", "Creating private subnets route table")
    success, ret = oci_manager.create_private_route_table(
        vcn_id=sysconfig['oci']['network']['vcn']['id'],
        route_table_name="HyDR_private_subnet_route_table",
        service_gateway_id=sysconfig['oci']['network']['service_gateway']['id'],
        nat_gateway_id=sysconfig['oci']['network']['nat_gateway']['id']
    )
    if not success:
        logger.writelog("info", "Failed to create private subnets route table")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Successfully created private subnets route table")
    sysconfig['oci']['network']['vcn']['private_route_table_id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # create public subnets route table
    logger.writelog("info", "Creating public subnets route table")
    success, ret = oci_manager.create_public_route_table(
        vcn_id=sysconfig['oci']['network']['vcn']['id'],
        route_table_name="HyDR_public_subnet_route_table",
        internet_gateway_id=sysconfig['oci']['network']['internet_gateway']['id']
    )
    if not success:
        logger.writelog("info", "Failed to create public subnets route table")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Successfully created public subnets route table")
    sysconfig['oci']['network']['vcn']['public_route_table_id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)


    ### CREATE SECURITY LISTS FOR SUBNETS

    if 'security_lists' not in sysconfig['oci']['network'].keys():
        sysconfig['oci']['network']['security_lists'] = {}
    logger.writelog("info", "Creating security lists for subnets")
    for subnet_type, subnet_details in sysconfig['oci']['network']['subnets'].items():
        logger.writelog("info", f"Creating security list [{subnet_details['name']}_security_list] for subnet [{subnet_details['name']}]")
        success, ret = oci_manager.create_security_list(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            display_name=f"{subnet_details['name']}_security_list"
        )
        if not success:
            logger.writelog("error", f"Could not create security list [{subnet_details['name']}_security_list]")
            sys.exit(1)

        if subnet_type not in sysconfig['oci']['network']['security_lists'].keys():
            sysconfig['oci']['network']['security_lists'][subnet_type] = {}
        sysconfig['oci']['network']['security_lists'][subnet_type]['name'] = ret.display_name
        sysconfig['oci']['network']['security_lists'][subnet_type]['id'] = ret.id

    save_sysconfig(sysconfig, sysconfig_file)

    # CONFIGURE SECURITY LISTS

    # webtier
    logger.writelog("info", "Configuring webtier security rules")
    # allow ssh access from bastion if bastion in OCI
    if sysconfig['bastion']['location'] == 'oci':
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
            source=sysconfig['bastion']['private_ip'],
            description="Allow SSH access from bastion server to web-tier subnet",
            port="22",
            source_type='IP'
        )
        if not success:
            logger.writelog("error", "Could not open SSH port from bastion server to web-tier subnet")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened SSH port 22 from bastion server to web-tier subnet")

    # allow access to all inside webtier CIDR
    logger.writelog("debug", "Allowing full ingress access inside webtier CIDR")
    success, ret = oci_manager.open_ingress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
        source_cidr=sysconfig['oci']['network']['subnets']['webtier']['cidr'],
        description="Allow all ingress inside this web-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating webtier security list to allow full ingress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all ingress inside webtier")
    logger.writelog("debug", "Allowing full egress access inside webtier CIDR")
    success, ret = oci_manager.open_egress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['webtier']['cidr'],
        description="Allow all egress inside this web-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating webtier security list to allow full egress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all egress inside webtier")

    logger.writelog("debug", "Opening ingress frontend and ssh ports from on-prem")
    for port in sysconfig['oci']['lbr']['https_port'], \
                LBR_HTTP_PORT, \
                sysconfig['oci']['lbr']['admin_port'], \
                sysconfig['oci']['network']['ports']['ssh']:
        if port:
            logger.writelog("debug", f"Opening port {port}")
            success, reason = oci_manager.open_ingress_tcp_port(
                security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
                source=sysconfig['prem']['network']['cidr'],
                description=f"Allow access from on-prem network to frontend {port} port",
                port=port
            )
            if not success:
                logger.writelog("error", f"Could not open port {port}")
                logger.writelog("debug", reason)
                sys.exit(1)
            logger.writelog("debug", f"Opened port {port}")

    logger.writelog("debug", "Opening ingress frontend ports from midtier")
    for port in sysconfig['oci']['lbr']['https_port'], \
                LBR_HTTP_PORT:
        logger.writelog("debug", f"Opening port {port}")
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
            source=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            description=f"Allow access from mid-tier network to frontend {port} port",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened port {port}")

    logger.writelog("info", "Opening ingress frontend HTTPS port {0} from NAT GW IP".format(
        sysconfig['oci']['lbr']['https_port']
    ))
    success, reason = oci_manager.open_ingress_tcp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
        source=sysconfig['oci']['network']['nat_gateway']['ip'],
        description="Allow access from NAT GW IP to frontend HTTPS port {0}".format(
            sysconfig['oci']['lbr']['https_port']
        ),
        source_type='IP',
        port=sysconfig['oci']['lbr']['https_port']
    )
    if not success:
        logger.writelog("error", "Could not open frontend HTTPS port {0} from NAT GW IP".format(
            sysconfig['oci']['lbr']['https_port']
        ))
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened frontend HTTPS port {0} from NAT GW IP".format(
        sysconfig['oci']['lbr']['https_port']
    ))

    if sysconfig['oci']['lbr']['admin_port']:
        logger.writelog("info", "Opening ingress frontend admin port {0} from NAT GW IP".format(
            sysconfig['oci']['lbr']['admin_port']
        ))
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
            source=sysconfig['oci']['network']['nat_gateway']['ip'],
            description="Allow access from NAT GW IP to frontend admin port {0}".format(
                sysconfig['oci']['lbr']['admin_port']
            ),
            source_type='IP',
            port=sysconfig['oci']['lbr']['admin_port']
        )
        if not success:
            logger.writelog("error", "Could not open frontend admin port {0} from NAT GW IP".format(
                sysconfig['oci']['lbr']['admin_port']
            ))
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", "Opened frontend admin port {0} from NAT GW IP".format(
            sysconfig['oci']['lbr']['admin_port']
        ))

    logger.writelog("debug", "Updating webtier egress rules")
    logger.writelog("debug", "Opening outgoing admin server port")
    if sysconfig['oci']['ohs']['console_port']:
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
            destination_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            port=sysconfig['oci']['ohs']['console_port'],
            description="Allow outgoing access from web-tier to mid-tier {0} port".format(sysconfig['oci']['ohs']['console_port'])
        )
        if not success:
            logger.writelog("error", "Could not open outgoing port {0}".format(sysconfig['oci']['ohs']['console_port']))
            logger.writelog("debug", reason)
            sys.exit(1)            
        logger.writelog("debug", "Opened outgoing port {0}".format(sysconfig['oci']['ohs']['console_port']))

    logger.writelog("debug", "Opening outgoing WLS servers ports")
    for port in sysconfig['oci']['network']['ports']['wlsservers']:
        logger.writelog("debug", f"Opening outgoing port {port}")
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
            destination_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            port=port,
            description=f"Allow outgoing access from web-tier to mid-tier {port} port"
        )
        if not success:
            logger.writelog("error", f"Could not open outgoing port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened outgoing port {port}")

    # GitLab #16 egress access for yum 
    logger.writelog("debug", "Opening web-tier egress 443 port to OSN") 
    success, reason = oci_manager.open_egress_port_osn(
        security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id'],
        osn_cidr=sysconfig['oci']['network']['service_gateway']['cidr'],
        description="Allow outgoing access from web-tier on port 443 to OSN",
        port=443
    )
    if not success:
        logger.writelog("error", "Could not open web-tier egress 443 port to OSN")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened web-tier egress 443 port to OSN") 

    # midtier
    logger.writelog("info", "Configuring midtier security rules")
    # allow ssh access from bastion if bastion in OCI
    if sysconfig['bastion']['location'] == 'oci':
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            source=sysconfig['bastion']['private_ip'],
            description="Allow SSH access from bastion server to midtier subnet",
            port="22",
            source_type='IP'
        )
        if not success:
            logger.writelog("error", "Could not open SSH port from bastion server to midtier subnet")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened SSH port 22 from bastion server to midtier subnet")
    # allow access to all inside midtier CIDR
    logger.writelog("debug", "Allowing full ingress access inside midtier CIDR")
    success, ret = oci_manager.open_ingress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        source_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
        description="Allow all ingress inside this mid-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating midtier security list to allow full ingress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all ingress inside midtier")
    logger.writelog("debug", "Allowing full egress access inside midtier CIDR")
    success, ret = oci_manager.open_egress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
        description="Allow all egress inside this mid-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating midtier security list to allow full egress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all egress inside midtier")

    # allow from on-prem to different ports
    logger.writelog("debug", "Opening ssh and admin server (if used) ports from on-prem to midtier")
    for port in sysconfig['oci']['network']['ports']['ssh'], \
                sysconfig['oci']['ohs']['console_port']:
        if port:
            success, reason = oci_manager.open_ingress_tcp_port(
                security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
                source=sysconfig['prem']['network']['cidr'],
                description=f"Allow access from on-prem network to {port} port",
                port=port
            )
            if not success:
                logger.writelog("error", f"Could not open midtier ingress port {port}")
                logger.writelog("debug", reason)
                sys.exit(1)
            logger.writelog("debug", f"Opened midtier ingress port {port}")

    # allow wls servers ports from on-prem
    logger.writelog("debug", "Opening wls servers ports from on-prem to midtier")
    for port in sysconfig['oci']['network']['ports']['wlsservers']:
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            source=sysconfig['prem']['network']['cidr'],
            description=f"Allow access from on-prem network to {port} port",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open midtier ingress port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened midtier ingress port {port}")

    # allow from webtier to admin server port - if admin server used
    if sysconfig['oci']['ohs']['console_port']:
        logger.writelog("debug", "Opening admin server port from webtier")
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            source=sysconfig['oci']['network']['subnets']['webtier']['cidr'],
            description="Allow access from web-tier network to admin port {0}".format(
                sysconfig['oci']['ohs']['console_port']),
            port=sysconfig['oci']['ohs']['console_port']
        )
        if not success:
            logger.writelog("error", "Could not open midtier ingress admin port {0}".format(
                sysconfig['oci']['ohs']['console_port']))
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", "Opened midtier ingress admin port {0}".format(
            sysconfig['oci']['ohs']['console_port']
        ))

    # allow from midtier wls servers ports
    logger.writelog("debug", "Opening wls servers ports from webtier to midtier")
    for port in sysconfig['oci']['network']['ports']['wlsservers']:
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            source=sysconfig['oci']['network']['subnets']['webtier']['cidr'],
            description=f"Allow access from web-tier network to {port} port",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open midtier ingress port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened midtier ingress port {port}")

    # rules to access to FSS subnet
    # stateful ingress from source mount target CIDR block TCP ports 111, 2048, 2049, and 2050 to ALL ports
    # stateful ingress from source mount target CIDR block UDP port 111 to ALL ports
    logger.writelog("debug", "Opening port 111 from fss-tier to mid-tier (TCP)")
    success, reason = oci_manager.open_ingress_tcp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        source=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow access from FSS-tier network  ports 111 to ALL (TCP)",
        port=111
    )
    if not success:
        logger.writelog("error", "Could not open midtier ingress port 111 (TCP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened midtier ingress port 111 (TCP)")

    logger.writelog("debug", "Opening ports 2048, 2049, and 2050 from fss-tier to mid-tier")
    for port in [2048, 2049, 2050]:
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            source=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
            description=f"Allow access from FSS-tier network port {port} to ALL ports (TCP)",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open midtier ingress port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened midtier ingress port {port}")

    logger.writelog("debug", "Opening port 111 from fss-tier to mid-tier (UDP)")
    success, reason = oci_manager.open_ingress_udp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        source_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow access from FSS-tier network ports 111 to ALL (UDP)",
        port=111
    )
    if not success:
        logger.writelog("error", "Could not open midtier ingress port 111 (UDP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened midtier ingress port 111 (UDP)")

    logger.writelog("debug", "Opening egress port 111 from mid-tier to fss-tier (TCP)")
    success, reason = oci_manager.open_egress_tcp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow outgoing access from ALL ports to FSS-tier network ports 111 (TCP)",
        port=111
    )
    if not success:
        logger.writelog("error", "Could not open midtier egress port 111 (TCP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", f"Opened midtier to fss-tier egress port 111 (TCP)")

    logger.writelog("debug", "Opening egress port 111 from mid-tier to fss-tier (UDP)")
    success, reason = oci_manager.open_egress_udp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow outgoing access from ALL ports to FSS-tier network ports 111 (UDP)",
        port=111
    )
    if not success:
        logger.writelog("error", "Could not open midtier egress port 111 (UDP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", f"Opened midtier to fss-tier egress port 111 (UDP)")

    logger.writelog("debug", "Opening egress ports 2048, 2049, and 2050 from mid-tier to ffs-tier (TCP)")
    for port in [2048, 2049, 2050]:
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            destination_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
            description=f"Allow outgoing access from ALL ports to FSS-tier network port {port} (TCP)",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open midtier egress port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened midtier egress port {port}")

    logger.writelog("debug", "Opening egress port 2048 from mid-tier to fss-tier (UDP)")
    success, reason = oci_manager.open_egress_udp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow outgoing access from ALL ports to FSS-tier network ports 111 (UDP)",
        port=2048
    )
    if not success:
        logger.writelog("error", f"Could not open midtier to fss-tier egress port 2048 (UDP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened midtier to fss-tier egress port 2048 (UDP)")

    # egress rules from mid-tier to db-tier
    db_ports = []
    if isinstance(sysconfig['oci']['network']['ports']['sqlnet'], list):
        db_ports.extend(sysconfig['oci']['network']['ports']['sqlnet'])
    else:
        db_ports.append(sysconfig['oci']['network']['ports']['sqlnet'])
    if isinstance(sysconfig['oci']['network']['ports']['ons'], list):
        db_ports.extend(sysconfig['oci']['network']['ports']['ons'])
    else:
        db_ports.append(sysconfig['oci']['network']['ports']['ons'])
    for port in db_ports:
        logger.writelog("debug", f"Opening midtier to db-tier egress port {port} (TCP)")                
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            destination_cidr=sysconfig['oci']['network']['subnets']['dbtier']['cidr'],
            description="Allow outgoing access from mid-tier to db-tier Database listener and ons ports",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open midtier to db-tier egress port {port} (TCP)")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened midtier to db-tier egress port {port} (TCP)")

    # egress rules from mid-tier to on-prem SSH
    logger.writelog("debug", "Opening midtier to on-prem egress ssh port")      
    success, reason = oci_manager.open_egress_tcp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        destination_cidr=sysconfig['prem']['network']['cidr'],
        description="Allow outgoing access from mid-tier to on-prem SSH port",
        port=sysconfig['oci']['network']['ports']['ssh']
    )
    if not success:
        logger.writelog("error", f"Could not open midtier to on-prem egress ssh port")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", f"Opened midtier to on-prem egress ssh port")

    # Egress rules from mid-tier to HTTPS and admin ports (needed for potential application callbacks to LBR )
    if sysconfig['oci']['network']['subnets']['webtier']['private'] == "Yes":
        destination = sysconfig['oci']['network']['subnets']['webtier']['cidr']
    else:
        destination = "0.0.0.0/0"
    logger.writelog("debug", "Opening egress HTTPS port from mid-tier to web-tier") 
    success, reason = oci_manager.open_egress_tcp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        destination_cidr=destination,
        description="Allow outgoing access from mid-tier to web-tier HTTPS port",
        port=sysconfig['oci']['lbr']['https_port']
    )
    if not success:
        logger.writelog("error", "Could not open egress HTTPS port from mid-tier to web-tier")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened egress HTTPS port from mid-tier to web-tier") 

    if sysconfig['oci']['lbr']['admin_port']:
        logger.writelog("debug", "Opening egress admin port {0} from mid-tier to web-tier".format(
            sysconfig['oci']['lbr']['admin_port']
        )) 
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
            destination_cidr=destination,
            description="Allow outgoing access from mid-tier to web-tier admin port",
            port=sysconfig['oci']['lbr']['admin_port']
        )
        if not success:
            logger.writelog("error", "Could not open egress admin port {0} from mid-tier to web-tier".format(
                sysconfig['oci']['lbr']['admin_port']
            ))
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", "Opened egress admin port {0} from mid-tier to web-tier".format(
            sysconfig['oci']['lbr']['admin_port']
        )) 

    # GitLab #16 egress access for yum 
    logger.writelog("debug", "Opening mid-tier egress 443 port to OSN") 
    success, reason = oci_manager.open_egress_port_osn(
        security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id'],
        osn_cidr=sysconfig['oci']['network']['service_gateway']['cidr'],
        description="Allow outgoing access from mid-tier on port 443 to OSN",
        port=443
    )
    if not success:
        logger.writelog("error", "Could not open mid-tier egress 443 port to OSN")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened mid-tier egress 443 port to OSN") 

    # dbtier
    logger.writelog("info", "Configuring dbtier security rules")
    # allow ssh access from bastion if bastion in OCI
    if sysconfig['bastion']['location'] == 'oci':
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id'],
            source=sysconfig['bastion']['private_ip'],
            description="Allow SSH access from bastion server to dbtier subnet",
            port="22",
            source_type='IP'
        )
        if not success:
            logger.writelog("error", "Could not open SSH port from bastion server to dbtier subnet")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened SSH port 22 from bastion server to dbtier subnet")
    # allow access to all inside dbtier CIDR
    logger.writelog("debug", "Allowing full ingress access inside dbtier CIDR")
    success, ret = oci_manager.open_ingress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id'],
        source_cidr=sysconfig['oci']['network']['subnets']['dbtier']['cidr'],
        description="Allow all ingress inside this db-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating dbtier security list to allow full ingress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all ingress inside dbtier")
    logger.writelog("debug", "Allowing full egress access inside dbtier CIDR")
    success, ret = oci_manager.open_egress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['dbtier']['cidr'],
        description="Allow all egress inside this db-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating dbtier security list to allow full egress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all egress inside dbtier")

    # Allow access from on-prem to SSH and SQLNET port
    logger.writelog("debug", "Opening SSH and SQLNET ports from on-prem to dbtier")
    prem_db_ports = []
    if isinstance(sysconfig['oci']['network']['ports']['sqlnet'], list):
        prem_db_ports.extend(sysconfig['oci']['network']['ports']['sqlnet'])
    else:
        prem_db_ports.append(sysconfig['oci']['network']['ports']['sqlnet'])
    if isinstance(sysconfig['oci']['network']['ports']['ssh'], list):
        prem_db_ports.extend(sysconfig['oci']['network']['ports']['ssh'])
    else:
        prem_db_ports.append(sysconfig['oci']['network']['ports']['ssh'])
    for port in prem_db_ports:
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id'],
            source=sysconfig['prem']['network']['cidr'],
            description=f"Allow access from on-prem network to {port} port",
            port=port
        )
        if not success:
            logger.writelog("error", f"Failed opening port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened port {port} from on-prem to dbtier")

    # Allow access from mid-tier to SQLNET and ONS ports
    mid_db_ports = []
    if isinstance(sysconfig['oci']['network']['ports']['sqlnet'], list):
        mid_db_ports.extend(sysconfig['oci']['network']['ports']['sqlnet'])
    else:
        mid_db_ports.append(sysconfig['oci']['network']['ports']['sqlnet'])
    if isinstance(sysconfig['oci']['network']['ports']['ons'], list):
        mid_db_ports.extend(sysconfig['oci']['network']['ports']['ons'])
    else:
        mid_db_ports.append(sysconfig['oci']['network']['ports']['ons'])
    logger.writelog("debug", "Opening SQLNET and ONS ports from midtier to dbtier")
    for port in mid_db_ports:
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id'],
            source=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            description="Allow access from mid-tier network to SQLNET and ONS port",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open port {port}")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened port {port}")

    # Egress rules from db-tier to on-prem
    logger.writelog("debug", "Opening SQLNET egress ports from dbtier to on-prem")
    sqlnet_ports = []
    if isinstance(sysconfig['oci']['network']['ports']['sqlnet'], list):
        sqlnet_ports.extend(sysconfig['oci']['network']['ports']['sqlnet'])
    else:
        sqlnet_ports.append(sysconfig['oci']['network']['ports']['sqlnet'])
    for port in sqlnet_ports:
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id'],
            destination_cidr=sysconfig['prem']['network']['cidr'],
            description="Allow outgoing access from db-tier to on-prem Database listener port",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open egress sqlnet port [{port}] from dbtier to on-prem")
            logger.writelog("debug", reason)
        logger.writelog("debug", f"Opened egress SQLNET port [{port}] from dbtier to on-prem")

    # fsstier
    logger.writelog("info", "Configuring fsstier security rules")
    # allow ssh access from bastion if bastion in OCI
    if sysconfig['bastion']['location'] == 'oci':
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
            source=sysconfig['bastion']['private_ip'],
            description="Allow SSH access from bastion server to fsstier subnet",
            port="22",
            source_type='IP'
        )
        if not success:
            logger.writelog("error", "Could not open SSH port from bastion server to fsstier subnet")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened SSH port 22 from bastion server to fsstier subnet")
    # allow all inside fsstier
    logger.writelog("debug", "Allowing full ingress access inside fsstier CIDR")
    success, ret = oci_manager.open_ingress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
        source_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow all ingress inside this fss-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating fsstier security list to allow full ingress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all ingress inside fsstier")
    logger.writelog("debug", "Allowing full egress access inside fsstier CIDR")
    success, ret = oci_manager.open_egress_all(
        security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
        description="Allow all egress inside this fss-tier subnet"
    )
    if not success:
        logger.writelog("error", "Updating fsstier security list to allow full egress access inside failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("debug", "Opened all egress inside fsstier")

    # Stateful ingress allow access from mid-tier to FSS (from ALL ports in the source instance CIDR block to TCP ports 111, 2048, 2049, and 2050)
    # Stateful ingress allow access from mid-tier to FSS (from ALL ports in the source instance CIDR block to UDP ports 111 and 2048)   
    logger.writelog("debug", "Opening port 111 fsstier (TCP)") 
    success, reason = oci_manager.open_ingress_tcp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
        source=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
        description="Allow access from ALL ports in the mid-tier network to port 111 (TCP)",
        port=111
    )
    if not success:
        logger.writelog("error", "Could not open fsstier port 111 (TCP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened fsstier port 111(TCP)")

    logger.writelog("debug", "Opening ports 2048, 2049, and 2050 from midtier to fsstier")
    for port in [2048, 2049, 2050]:
        success, reason = oci_manager.open_ingress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
            source=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            description=f"Allow access from ALL ports in the mid-tier network to port {port}(TCP)",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open fsstier ingress port {port} (TCP)")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened fsstier ingress port {port} (TCP)")

    logger.writelog("debug", "Opening fsstier ports 111 and 2048 (UDP)")
    for port in [111, 2048]:
        success, reason = oci_manager.open_ingress_udp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
            source_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            description=f"Allow access from ALL ports in the mid-tier network to port {port}(UDP)",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open fsstier ingress port {port} (UDP)")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened fsstier ingress port {port} (UDP)")

    # Stateful egress from TCP ports 111, 2048, 2049, and 2050 to ALL ports in the destination instance CIDR block
    # Stateful egress from UDP port 111 ALL ports in the destination instance CIDR block.

    logger.writelog("debug", "Opening egress fsstier ports 111, 2048, 2049 and 2050 (TCP)")
    for port in [111, 2048, 2049, 2050]:
        success, reason = oci_manager.open_egress_tcp_port(
            security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
            destination_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            description=f"Allow outgoing from port {port} to mid-tier network ALL ports (TCP)",
            port=port
        )
        if not success:
            logger.writelog("error", f"Could not open fsstier egress port {port} (TCP)")
            logger.writelog("debug", reason)
            sys.exit(1)
        logger.writelog("debug", f"Opened fsstier egress port {port} (TCP)")

    logger.writelog("debug", "Opening fsstier egress port 111 (UDP)")
    success, reason = oci_manager.open_egress_udp_port(
        security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id'],
        destination_cidr=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
        description="Allow outgoing from ALL ports to to mid-tier network ports 111 (UDP)",
        port=111
    )
    if not success:
        logger.writelog("error", "Could not open fsstier egress port 111 (UDP)")
        logger.writelog("debug", reason)
        sys.exit(1)
    logger.writelog("debug", "Opened fsstier egress port 111 (UDP)")

    ### CREATE SUBNETS
    # webtier
    # if create VCN set to no check if webtier subnet already exists - create if not/retrieve info if yes
    if sysconfig['oci']['network']['vcn']['create'] == "Yes":
        logger.writelog("info", "Creating webtier subnet")
        CREATE_WEBTIER = True
    else:
        logger.writelog("info", "Checking if webtier subnet {0} exists".format(
            sysconfig['oci']['network']['subnets']['webtier']['name']
        ))
        success, ret = oci_manager.get_subnet_by_name(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            subnet_name=sysconfig['oci']['network']['subnets']['webtier']['name']
        )
        if not success:
            logger.writelog("error", "Failed querying OCI for webtier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        if ret is None:
            CREATE_WEBTIER = True
            logger.writelog("info", "Webtier subnet {0} does not exist - creating".format(
                sysconfig['oci']['network']['subnets']['webtier']['name']
            ))
        else:
            CREATE_WEBTIER = False
            logger.writelog("info", "Webtier subnet {0} already exists - retrieved details".format(
                sysconfig['oci']['network']['subnets']['webtier']['name']
            ))
            sysconfig['oci']['network']['subnets']['webtier']['id'] = ret.id
            logger.writelog("info", "Adding security list {0} to subnet".format(
                sysconfig['oci']['network']['security_lists']['webtier']['name']
            ))
            success, ret = oci_manager.add_sec_list_subnet(
                vcn_id=sysconfig['oci']['network']['vcn']['id'], 
                subnet_id=sysconfig['oci']['network']['subnets']['webtier']['id'], 
                security_list_id=sysconfig['oci']['network']['security_lists']['webtier']['id']
            )
            if not success:
                logger.writelog("error", "Failed to add security list")
                logger.writelog("debug", ret)
            else:
                logger.writelog("info", "Successfully added security list")
    if CREATE_WEBTIER:
        if sysconfig['oci']['network']['subnets']['webtier']['private'] == "Yes":
            is_private = True
            route_table = sysconfig['oci']['network']['vcn']['private_route_table_id']
        else:
            is_private = False
            route_table = sysconfig['oci']['network']['vcn']['public_route_table_id']
        success, ret = oci_manager.create_subnet(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            cidr_block=sysconfig['oci']['network']['subnets']['webtier']['cidr'],
            subnet_name=sysconfig['oci']['network']['subnets']['webtier']['name'],
            is_private=is_private,
            security_list_ids=[sysconfig['oci']['network']['security_lists']['webtier']['id']],
            route_table_id=route_table
        )
        if not success:
            logger.writelog("error", "Could not create webtier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created webtier subnet")
        sysconfig['oci']['network']['subnets']['webtier']['id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # midtier
    # if create VCN set to no check if midtier subnet already exists - create if not/retrieve info if yes
    if sysconfig['oci']['network']['vcn']['create'] == "Yes":
        logger.writelog("info", "Creating midtier subnet")
        CREATE_MIDTIER = True
    else:
        logger.writelog("info", "Checking if midtier subnet {0} exists".format(
            sysconfig['oci']['network']['subnets']['midtier']['name']
        ))
        success, ret = oci_manager.get_subnet_by_name(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            subnet_name=sysconfig['oci']['network']['subnets']['midtier']['name']
        )
        if not success:
            logger.writelog("error", "Failed querying OCI for midtier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)           
        if ret is None:
            CREATE_MIDTIER = True
            logger.writelog("info", "Midtier subnet {0} does not exist - creating".format(
                sysconfig['oci']['network']['subnets']['midtier']['name']
            ))
        else:
            CREATE_MIDTIER = False
            logger.writelog("info", "Midtier subnet {0} already exists - retrieved details".format(
                sysconfig['oci']['network']['subnets']['midtier']['name']
            ))
            sysconfig['oci']['network']['subnets']['midtier']['id'] = ret.id
            logger.writelog("info", "Adding security list {0} to subnet".format(
                sysconfig['oci']['network']['security_lists']['midtier']['name']
            ))
            success, ret = oci_manager.add_sec_list_subnet(
                vcn_id=sysconfig['oci']['network']['vcn']['id'], 
                subnet_id=sysconfig['oci']['network']['subnets']['midtier']['id'], 
                security_list_id=sysconfig['oci']['network']['security_lists']['midtier']['id']
            )
            if not success:
                logger.writelog("error", "Failed to add security list")
                logger.writelog("debug", ret)
            else:
                logger.writelog("info", "Successfully added security list")
    if CREATE_MIDTIER:
        if sysconfig['oci']['network']['subnets']['midtier']['private'] == "Yes":
            is_private = True
            route_table = sysconfig['oci']['network']['vcn']['private_route_table_id']
        else:
            is_private = False
            route_table = sysconfig['oci']['network']['vcn']['public_route_table_id']
        success, ret = oci_manager.create_subnet(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            cidr_block=sysconfig['oci']['network']['subnets']['midtier']['cidr'],
            subnet_name=sysconfig['oci']['network']['subnets']['midtier']['name'],
            is_private=True if sysconfig['oci']['network']['subnets']['midtier']['private'] == "Yes" else False,
            security_list_ids=[sysconfig['oci']['network']['security_lists']['midtier']['id']],
            route_table_id=route_table
        )
        if not success:
            logger.writelog("error", "Could not create midtier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created midtier subnet")
        sysconfig['oci']['network']['subnets']['midtier']['id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # dbtier
    # if create VCN set to no check if dbtier subnet already exists - create if not/retrieve info if yes
    if sysconfig['oci']['network']['vcn']['create'] == "Yes":
        logger.writelog("info", "Creating dbtier subnet")
        CREATE_DBTIER = True
    else:
        logger.writelog("info", "Checking if dbtier subnet {0} exists".format(
            sysconfig['oci']['network']['subnets']['dbtier']['name']
        ))
        success, ret = oci_manager.get_subnet_by_name(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            subnet_name=sysconfig['oci']['network']['subnets']['dbtier']['name']
        )
        if not success:
            logger.writelog("error", "Failed querying OCI for dbtier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        if ret is None:
            CREATE_DBTIER = True
            logger.writelog("info", "Dbtier subnet {0} does not exist - creating".format(
                sysconfig['oci']['network']['subnets']['dbtier']['name']
            ))
        else:
            CREATE_DBTIER = False
            logger.writelog("info", "Dbtier subnet {0} already exists - retrieved details".format(
                sysconfig['oci']['network']['subnets']['dbtier']['name']
            ))
            sysconfig['oci']['network']['subnets']['dbtier']['id'] = ret.id
            logger.writelog("info", "Adding security list {0} to subnet".format(
                sysconfig['oci']['network']['security_lists']['dbtier']['name']
            ))
            success, ret = oci_manager.add_sec_list_subnet(
                vcn_id=sysconfig['oci']['network']['vcn']['id'], 
                subnet_id=sysconfig['oci']['network']['subnets']['dbtier']['id'], 
                security_list_id=sysconfig['oci']['network']['security_lists']['dbtier']['id']
            )
            if not success:
                logger.writelog("error", "Failed to add security list")
                logger.writelog("debug", ret)
            else:
                logger.writelog("info", "Successfully added security list")
    if CREATE_DBTIER:
        if sysconfig['oci']['network']['subnets']['dbtier']['private'] == "Yes":
            is_private = True
            route_table = sysconfig['oci']['network']['vcn']['private_route_table_id']
        else:
            is_private = False
            route_table = sysconfig['oci']['network']['vcn']['public_route_table_id']        
        success, ret = oci_manager.create_subnet(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            cidr_block=sysconfig['oci']['network']['subnets']['dbtier']['cidr'],
            subnet_name=sysconfig['oci']['network']['subnets']['dbtier']['name'],
            is_private=True if sysconfig['oci']['network']['subnets']['dbtier']['private'] == "Yes" else False,
            security_list_ids=[sysconfig['oci']['network']['security_lists']['dbtier']['id']],
            route_table_id=route_table
        )
        if not success:
            logger.writelog("error", "Could not create dbtier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created dbtier subnet")
        sysconfig['oci']['network']['subnets']['dbtier']['id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # fsstier
    # if create VCN set to no check if fsstier subnet already exists - create if not/retrieve info if yes
    if sysconfig['oci']['network']['vcn']['create'] == "Yes":
        logger.writelog("info", "Creating fsstier subnet")
        CREATE_FSSTIER = True
    else:
        logger.writelog("info", "Checking if fsstier subnet {0} exists".format(
            sysconfig['oci']['network']['subnets']['fsstier']['name']
        ))
        success, ret = oci_manager.get_subnet_by_name(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            subnet_name=sysconfig['oci']['network']['subnets']['fsstier']['name']
        )
        if not success:
            logger.writelog("error", "Failed querying OCI for fsstier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        if ret is None:
            CREATE_FSSTIER = True
            logger.writelog("info", "Fsstier subnet {0} does not exist - creating".format(
                sysconfig['oci']['network']['subnets']['fsstier']['name']
            ))
        else:
            CREATE_FSSTIER = False
            logger.writelog("info", "Fsstier subnet {0} already exists - retrieved details".format(
                sysconfig['oci']['network']['subnets']['fsstier']['name']
            ))
            sysconfig['oci']['network']['subnets']['fsstier']['id'] = ret.id
            logger.writelog("info", "Adding security list {0} to subnet".format(
                sysconfig['oci']['network']['security_lists']['fsstier']['name']
            ))
            success, ret = oci_manager.add_sec_list_subnet(
                vcn_id=sysconfig['oci']['network']['vcn']['id'], 
                subnet_id=sysconfig['oci']['network']['subnets']['fsstier']['id'], 
                security_list_id=sysconfig['oci']['network']['security_lists']['fsstier']['id']
            )
            if not success:
                logger.writelog("error", "Failed to add security list")
                logger.writelog("debug", ret)
            else:
                logger.writelog("info", "Successfully added security list")
    if CREATE_FSSTIER:
        if sysconfig['oci']['network']['subnets']['fsstier']['private'] == "Yes":
            is_private = True
            route_table = sysconfig['oci']['network']['vcn']['private_route_table_id']
        else:
            is_private = False
            route_table = sysconfig['oci']['network']['vcn']['public_route_table_id']
        success, ret = oci_manager.create_subnet(
            vcn_id=sysconfig['oci']['network']['vcn']['id'],
            cidr_block=sysconfig['oci']['network']['subnets']['fsstier']['cidr'],
            subnet_name=sysconfig['oci']['network']['subnets']['fsstier']['name'],
            is_private=True if sysconfig['oci']['network']['subnets']['fsstier']['private'] == "Yes" else False,
            security_list_ids=[sysconfig['oci']['network']['security_lists']['fsstier']['id']],
            route_table_id=route_table
        )
        if not success:
            logger.writelog("error", "Could not create fsstier subnet")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Successfully created fsstier subnet")
        sysconfig['oci']['network']['subnets']['fsstier']['id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # CREATE DHCP OPTION
    logger.writelog("info", "Creating DHCP options for search domain")
    success, ret = oci_manager.create_dhcp_search_domain(
        vcn_id=sysconfig['oci']['network']['vcn']['id'],
        search_domains=sysconfig['prem']['network']['fqdn'],
        display_name=DHCP_OPT_NAME,
    )
    if not success:
        logger.writelog("error", "Could not create DHCP search domain option")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Created DHCP search domain option")
    sysconfig['oci']['network']['dhcp'] = {}
    sysconfig['oci']['network']['dhcp']['name'] = DHCP_OPT_NAME
    sysconfig['oci']['network']['dhcp']['id'] = ret.id

    # Update midtier and webtier subnets DHCP option
    logger.writelog("info", "Updating midtier subnet DHCP option")
    success, ret = oci_manager.add_dhcp_opt_to_subnet(
        subnet_id=sysconfig['oci']['network']['subnets']['midtier']['id'],
        dhcp_opt_id=sysconfig['oci']['network']['dhcp']['id']
    )
    if not success:
        logger.writelog("error", "Could not update midtier subnet DHCP option")
        logger.writelog("debug", ret)
        sys.exit(1)

    logger.writelog("info", "Updating webtier subnet DHCP option")
    success, ret = oci_manager.add_dhcp_opt_to_subnet(
        subnet_id=sysconfig['oci']['network']['subnets']['webtier']['id'],
        dhcp_opt_id=sysconfig['oci']['network']['dhcp']['id']
    )
    if not success:
        logger.writelog("error", "Could not update webtier subnet DHCP option")
        logger.writelog("debug", ret)
        sys.exit(1)

    # CREATE BLOCK VOLUMES
    logger.writelog("info", "Creating block volumes")
    ad_modulo = len(sysconfig['oci']['availability_domains']) if sysconfig['oci']['round_robin'] == "Yes" else 1
    for idx in range(0, int(sysconfig['oci']['wls']['nodes_count'])):
        availability_domain = sysconfig['oci']['availability_domains'][idx % ad_modulo]
        logger.writelog("info", f"Creating block volume [{sysconfig['oci']['storage']['block_volumes'][idx]['name']}] in AD [{availability_domain}]")
        success, ret = oci_manager.create_block_volume(
            availability_domain=availability_domain,
            name=sysconfig['oci']['storage']['block_volumes'][idx]['name'],
            size_in_gb=50
        )
        if not success:
            logger.writelog("error", f"Could not create block volume [{sysconfig['oci']['storage']['block_volumes'][idx]['name']}] in AD [{availability_domain}]")
            logger.writelog("debug", ret)
            sys.exit(1)
        # save block volume details in sysconfig
        sysconfig['oci']['storage']['block_volumes'][idx]['id'] = ret.id
        logger.writelog("info", f"Created block volume [{sysconfig['oci']['storage']['block_volumes'][idx]['name']}] in AD [{availability_domain}]")

    save_sysconfig(sysconfig, sysconfig_file)

    # CREATE FILE SYSTEMS   
    logger.writelog("info", "Creating Filesystems")
    # shared config - only if supplied in input file
    if sysconfig['prem']['wls']['mountpoints']['config']:
        logger.writelog("info", f"Creating shared config filesystem [{sysconfig['oci']['storage']['fss']['sharedconfig']['name']}]")
        success, ret = oci_manager.create_filesystem(
            availability_domain=sysconfig['oci']['availability_domains'][0],
            name=sysconfig['oci']['storage']['fss']['sharedconfig']['name'],
        )
        if not success:
            logger.writelog("error", f"Could not create shared config filesystem [{sysconfig['oci']['storage']['fss']['sharedconfig']['name']}]")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Created shared config filesystem [{sysconfig['oci']['storage']['fss']['sharedconfig']['name']}]")
        sysconfig['oci']['storage']['fss']['sharedconfig']['id'] = ret.id
    else:
        logger.writelog("info", "WLS shared config not supplied - will not create")
    # runtime - only if supplied in input file
    if sysconfig['prem']['wls']['mountpoints']['runtime']:
        logger.writelog("info", f"Creating runtime filesystem [{sysconfig['oci']['storage']['fss']['runtime']['name']}]")
        success, ret = oci_manager.create_filesystem(
            availability_domain=sysconfig['oci']['availability_domains'][0],
            name=sysconfig['oci']['storage']['fss']['runtime']['name'],
        )
        if not success:
            logger.writelog("error", f"Could not create shared config filesystem [{sysconfig['oci']['storage']['fss']['runtime']['name']}]")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Created shared config filesystem [{sysconfig['oci']['storage']['fss']['runtime']['name']}]")
        sysconfig['oci']['storage']['fss']['runtime']['id'] = ret.id
    else:
        logger.writelog("info", "WLS shared runtime not supplied - will not create")
    # products
    for idx in range(0, len(sysconfig['oci']['storage']['fss']['products'])):
        availability_domain = sysconfig['oci']['availability_domains'][idx % ad_modulo]
        logger.writelog("info", f"Creating products filesystem [{sysconfig['oci']['storage']['fss']['products'][idx]['name']}]")
        success, ret = oci_manager.create_filesystem(
            availability_domain=availability_domain,
            name=sysconfig['oci']['storage']['fss']['products'][idx]['name'],
        )
        if not success:
            logger.writelog("error", f"Could not create shared config filesystem [{sysconfig['oci']['storage']['fss']['products'][idx]['name']}]")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Created shared config filesystem [{sysconfig['oci']['storage']['fss']['products'][idx]['name']}]")
        sysconfig['oci']['storage']['fss']['products'][idx]['id'] = ret.id       

    save_sysconfig(sysconfig, sysconfig_file)

    # CREATE MOUNT TARGETS
    logger.writelog("info", "Creating mount targets")
    for idx in range(0, len(sysconfig['oci']['storage']['fss']['mounttargets']['targets'])):
        logger.writelog("info", f"Creating mount target [{sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['name']}]")
        success, ret = oci_manager.create_mount_target(
            availability_domain=sysconfig['oci']['availability_domains'][idx % ad_modulo],
            subnet_id=sysconfig['oci']['network']['subnets']['fsstier']['id'],
            name=sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['name']
        )
        if not success:
            logger.writelog("error", f"Could not create mount target [{sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['name']}]")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Created mount target [{sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['name']}]")
        sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['id'] = ret.id
        sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['export_set_id'] = ret.export_set_id
        # now get the private ip to use later on to edit /etc/fstab on nodes
        success, ret = oci_manager.get_private_ip_by_id(ip_id=ret.private_ip_ids[0])
        if not success:
            logger.writelog("error", "Could not retrieve mount target IP")
            logger.writelog("debug", ret)
            sys.exit(1)
        sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx]['ip'] = ret
        save_sysconfig(sysconfig, sysconfig_file)

    # EXPORT FILESYSTEMS
    logger.writelog("info", "Exporting filesystems")
    # shared config - only if supplied in input file
    if sysconfig['prem']['wls']['mountpoints']['config']:
        logger.writelog("info", "Exporting shared config filesystem")
        success, ret = oci_manager.export_filesystem(
            export_set_id=sysconfig['oci']['storage']['fss']['mounttargets']['targets'][0]['export_set_id'],
            filesystem_id=sysconfig['oci']['storage']['fss']['sharedconfig']['id'],
            path=sysconfig['oci']['storage']['fss']['sharedconfig']['export_path']
        )
        if not success:
            logger.writelog("error", "Could not export shared config filesystem")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Succesfully exported shared config filesystem")
        sysconfig['oci']['storage']['fss']['sharedconfig']['export_id'] = ret.id
        sysconfig['oci']['storage']['fss']['sharedconfig']['export_ip'] = sysconfig['oci']['storage']['fss']['mounttargets']['targets'][0]['ip']
        save_sysconfig(sysconfig, sysconfig_file)
    else:
        logger.writelog("info", "WLS shared config filesystem not used - will not export")

    # runtime - only if supplied in input file
    if sysconfig['prem']['wls']['mountpoints']['runtime']:
        logger.writelog("info", "Exporting runtime filesystem")
        success, ret = oci_manager.export_filesystem(
            export_set_id=sysconfig['oci']['storage']['fss']['mounttargets']['targets'][0]['export_set_id'],
            filesystem_id=sysconfig['oci']['storage']['fss']['runtime']['id'],
            path=sysconfig['oci']['storage']['fss']['runtime']['export_path']
        )
        if not success:
            logger.writelog("error", "Could not export runtime filesystem")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Succesfully exported runtime filesystem")
        sysconfig['oci']['storage']['fss']['runtime']['export_id'] = ret.id
        sysconfig['oci']['storage']['fss']['runtime']['export_ip'] = sysconfig['oci']['storage']['fss']['mounttargets']['targets'][0]['ip']
        save_sysconfig(sysconfig, sysconfig_file)
    else:
        logger.writelog("info", "WLS shared runtime filesystem not used - will not export")

    # products
    for idx in range(0, len(sysconfig['oci']['storage']['fss']['products'])):
        logger.writelog("info", f"Exporting {sysconfig['oci']['storage']['fss']['products'][idx]['name']} filesystem")
        export_set_id = sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx % ad_modulo]['export_set_id']
        success, ret = oci_manager.export_filesystem(
            export_set_id=export_set_id,
            filesystem_id=sysconfig['oci']['storage']['fss']['products'][idx]['id'],
            path=sysconfig['oci']['storage']['fss']['products'][idx]['export_path']
        )
        if not success:
            logger.writelog("error", f"Could not export {sysconfig['oci']['storage']['fss']['products'][idx]['name']} filesystem")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Succesfully exported {sysconfig['oci']['storage']['fss']['products'][idx]['name']} filesystem")
        sysconfig['oci']['storage']['fss']['products'][idx]['export_id'] = ret.id
        sysconfig['oci']['storage']['fss']['products'][idx]['export_ip'] = sysconfig['oci']['storage']['fss']['mounttargets']['targets'][idx % ad_modulo]['ip']
        save_sysconfig(sysconfig, sysconfig_file)

    # CREATE LBR
    # creating lbr before provisioning wls instances so that we can add lbr ip to wls /etc/hosts
    logger.writelog("info", "Provisioning LBR")
    # check if webtier subnet is private or not - create LBR as such
    lbr_private = False
    if sysconfig['oci']['network']['subnets']['webtier']['private'] == "Yes":
        lbr_private = True
    success, ret = oci_manager.provision_lbr(
        min_bandwith_mbs=sysconfig['oci']['lbr']['min_bandwidth'],
        max_bandwith_mbs=sysconfig['oci']['lbr']['max_bandwidth'],
        name=sysconfig['oci']['lbr']['name'],
        subnet_id=sysconfig['oci']['network']['subnets']['webtier']['id'],
        is_private=lbr_private
    )
    if not success:
        logger.writelog("error", "LBR provisioning failed")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Successfully provisioned LBR")
    sysconfig['oci']['lbr']['id'] = ret.id
    sysconfig['oci']['lbr']['ip'] = ret.ip_addresses[0].ip_address
    save_sysconfig(sysconfig, sysconfig_file)

    # CREATE WLS INSTANCES 
    logger.writelog("info", "Creating WLS instances")
    with open(sysconfig['oci']['ssh_public_key'], "r") as f:
        ssh_key = f.read()
    # get all ports that need to be opened in instance firewall
    fw_ports = []
    fw_ports.extend(sysconfig['oci']['network']['ports']['wlsservers'])
    fw_ports.append(sysconfig['oci']['network']['ports']['node_manager'])
    coherence_ports = []
    if isinstance(sysconfig['oci']['network']['ports']['coherence'], list):
        coherence_ports = sysconfig['oci']['network']['ports']['coherence']
    else:
        coherence_ports = [sysconfig['oci']['network']['ports']['coherence']]
    # check if shared config filesystem is used otherwise leave vars black
    config_fs = ""
    config_mount = ""
    runtime_fs = ""
    runtime_mount = ""
    if sysconfig['prem']['wls']['mountpoints']['config']:
        config_fs = f"{sysconfig['oci']['storage']['fss']['sharedconfig']['export_ip']}:{sysconfig['oci']['storage']['fss']['sharedconfig']['export_path']}"
        config_mount = sysconfig['prem']['wls']['mountpoints']['config']
    if sysconfig['prem']['wls']['mountpoints']['runtime']:
        runtime_fs = f"{sysconfig['oci']['storage']['fss']['runtime']['export_ip']}:{sysconfig['oci']['storage']['fss']['runtime']['export_path']}"
        runtime_mount = sysconfig['prem']['wls']['mountpoints']['runtime']
    # build init script
    for idx in range(0, int(sysconfig['oci']['wls']['nodes_count'])):
        logger.writelog("info", f"Building WLS node {sysconfig['oci']['wls']['nodes'][idx]['name']} init script")
        node_init_script = f"{basedir}/lib/{sysconfig['oci']['wls']['nodes'][idx]['name']}_init.sh"
        with open(WLS_INIT_SCRIPT, "r") as infile:
            with open(node_init_script, "w") as outfile:
                for line in infile:
                    if re.match('.*%%"?$', line):
                        line = line.replace("%%OINSTALL_GID%%", 
                                            sysconfig['prem']['wls']['oinstall_gid'])
                        line = line.replace("%%ORACLE_UID%%", 
                                            sysconfig['prem']['wls']['oracle_uid'])
                        line = line.replace("%%CONFIG_FS%%", 
                                            #f"{sysconfig['oci']['storage']['fss']['sharedconfig']['export_ip']}:{sysconfig['oci']['storage']['fss']['sharedconfig']['export_path']}")
                                            config_fs)
                        line = line.replace("%%RUNTIME_FS%%", 
                                            # f"{sysconfig['oci']['storage']['fss']['runtime']['export_ip']}:{sysconfig['oci']['storage']['fss']['runtime']['export_path']}")
                                            runtime_fs)
                        line = line.replace("%%PRODUCTS_FS%%", 
                                            f"{sysconfig['oci']['storage']['fss']['products'][idx % ad_modulo]['export_ip']}:{sysconfig['oci']['storage']['fss']['products'][idx % ad_modulo]['export_path']}")
                        line = line.replace("%%CONFIG_MOUNT%%", 
                                            #f"{sysconfig['prem']['wls']['mountpoints']['config']}")
                                            config_mount)
                        line = line.replace("%%RUNTIME_MOUNT%%", 
                                            # f"{sysconfig['prem']['wls']['mountpoints']['runtime']}")
                                            runtime_mount)
                        line = line.replace("%%PRODUCTS_MOUNT%%", 
                                            f"{sysconfig['prem']['wls']['mountpoints']['products']}")
                        line = line.replace("%%PORTS%%", 
                                            f"({' '.join(fw_ports)})")
                        line = line.replace("%%COHERENCE_PORTS%%", 
                                            f"({' '.join(coherence_ports)})")
                        line = line.replace("%%SSH_PUB_KEY%%", ssh_key)
                        line = line.replace("%%LBR_IP%%", 
                                            f"{sysconfig['oci']['lbr']['ip']}")
                        line = line.replace("%%LBR_VIRT_HOSTNAME%%", 
                                            f"{sysconfig['oci']['lbr']['virtual_hostname_value']}")
                        if sysconfig['oci']['lbr']['admin_hostname_value']:
                            line = line.replace("%%LBR_ADMIN_HOSTNAME%%", 
                                                f"{sysconfig['oci']['lbr']['admin_hostname_value']}")
                        if sysconfig['oci']['lbr']['virt_host_hostname']:
                            line = line.replace("%%LBR_INTERNAL_VIRT_HOSTNAME%%", 
                                            f"{sysconfig['oci']['lbr']['virt_host_hostname']}")
                    outfile.write(line)
        logger.writelog("info", f"Creating WLS node {sysconfig['oci']['wls']['nodes'][idx]['name']}")
        success, ret = oci_manager.provision_instance(
            type="wls",
            name=sysconfig['oci']['wls']['nodes'][idx]['name'],
            os_version=sysconfig['oci']['wls']['os_version'],
            ocpu_count=sysconfig['oci']['wls']['ocpu'],
            memory=sysconfig['oci']['wls']['memory'],
            ssh_pub_key=ssh_key,
            subnet_id=sysconfig['oci']['network']['subnets']['midtier']['id'],
            availability_domain=sysconfig['oci']['availability_domains'][idx % ad_modulo],
            init_script_path=node_init_script
        )
        if not success:
            logger.writelog("error", "Failed provisioning WLS instance")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Created WLS node {sysconfig['oci']['wls']['nodes'][idx]['name']}")
        sysconfig['oci']['wls']['nodes'][idx]['id'] = ret.id
        save_sysconfig(sysconfig, sysconfig_file)
        logger.writelog("info", "Retrieving assigned IP address")
        success, ret = oci_manager.get_instance_ip(instance_id=sysconfig['oci']['wls']['nodes'][idx]['id'])
        if not success:
            logger.writelog("error", "Failed retrieving instance IP address")
            logger.writelog("debug", ret)
            sys.exit(1)
        sysconfig['oci']['wls']['nodes'][idx]['ip'] = ret
        save_sysconfig(sysconfig, sysconfig_file)

    # CREATE OHS instances
    logger.writelog("info", "Creating OHS instances")
    with open(sysconfig['oci']['ssh_public_key'], "r") as f:
        ssh_key = f.read()
    for idx in range(0, int(sysconfig['oci']['ohs']['nodes_count'])):
        logger.writelog("info", f"Building OHS node {sysconfig['oci']['ohs']['nodes'][idx]['name']} init script")
        node_init_script = f"{basedir}/lib/{sysconfig['oci']['ohs']['nodes'][idx]['name']}_init.sh"
        with open(OHS_INIT_SCRIPT, "r") as infile:
            with open(node_init_script, "w") as outfile:
                for line in infile:
                    if re.match('.*%%"?$', line):
                        line = line.replace("%%OINSTALL_GID%%", 
                                            sysconfig['prem']['ohs']['oinstall_gid'])
                        line = line.replace("%%ORACLE_UID%%", 
                                            sysconfig['prem']['ohs']['oracle_uid'])
                        line = line.replace("%%PORTS%%", "({0} {1} {2})".format(
                                                            sysconfig['oci']['ohs']['console_port'],
                                                            sysconfig['oci']['ohs']['http_port'],
                                                            sysconfig['oci']['lbr']['virt_host_ohs_port']
                                                            ))
                        line = line.replace("%%HOSTNAME_ALIAS%%", 
                                            sysconfig['prem']['ohs']['listen_addresses'][idx])
                        line = line.replace("%%PRODUCTS_PATH%%",
                                            sysconfig['prem']['ohs']['products_path'])
                        line = line.replace("%%PRIVATE_CFG_PATH%%",
                                            sysconfig['prem']['ohs']['config_path'])
                        line = line.replace("%%SSH_PUB_KEY%%", ssh_key)
                    outfile.write(line)
        logger.writelog("info", f"Creating OHS node {sysconfig['oci']['ohs']['nodes'][idx]['name']}")
        success, ret = oci_manager.provision_instance(
            type="ohs",
            name=sysconfig['oci']['ohs']['nodes'][idx]['name'],
            os_version=sysconfig['oci']['ohs']['os_version'],
            ocpu_count=sysconfig['oci']['ohs']['ocpu'],
            memory=sysconfig['oci']['ohs']['memory'],
            ssh_pub_key=ssh_key,
            subnet_id=sysconfig['oci']['network']['subnets']['webtier']['id'],
            availability_domain=sysconfig['oci']['availability_domains'][idx % ad_modulo],   
            init_script_path=node_init_script
        )
        if not success:
            logger.writelog("error", "Failed provisioning OHS instance")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Created OHS node {sysconfig['oci']['ohs']['nodes'][idx]['name']}")
        sysconfig['oci']['ohs']['nodes'][idx]['id'] = ret.id
        save_sysconfig(sysconfig, sysconfig_file)
        logger.writelog("info", "Retrieving assigned IP address")
        success, ret = oci_manager.get_instance_ip(instance_id=sysconfig['oci']['ohs']['nodes'][idx]['id'])
        if not success:
            logger.writelog("error", "Failed retrieving instance IP address")
            logger.writelog("debug", ret)
            sys.exit(1)
        sysconfig['oci']['ohs']['nodes'][idx]['ip'] = ret
        save_sysconfig(sysconfig, sysconfig_file)

    logger.writelog("info", "Waiting 3 minutes for instances to initialize")
    time.sleep(60 * 3)

    # check init script execution status on WLS nodes
    for idx in range(0, int(sysconfig['oci']['wls']['nodes_count'])):
        logger.writelog("info", f"Checking init script execution status on WLS node {sysconfig['oci']['wls']['nodes'][idx]['name']}")
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh.connect(username='opc',
                        hostname=sysconfig['oci']['wls']['nodes'][idx]['ip'],
                        key_filename=sysconfig['oci']['ssh_private_key'])
        except Exception as e:
            logger.writelog("error", f"Could not connect to instance {sysconfig['oci']['wls']['nodes'][idx]['name']}: {str(e)}")
            continue
        cmd = 'tail -1 /var/log/wls_init.log'
        logger.writelog("debug", f"Running {cmd} on {sysconfig['oci']['wls']['nodes'][idx]['name']}")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        out = stdout.read().decode()
        err = stderr.read().decode()
        ssh.close()
        logger.writelog("debug", f"stdout: {out}")
        logger.writelog("debug", f"stderr: {err}")
        if err:
            logger.writelog("error", f"Could not check init script execution: {err}")
            logger.writelog("error", "Check local logs on {0}, log path {1}".format(
                sysconfig['oci']['wls']['nodes'][idx]['name'],
                "/var/log/wls_init.log"
            ))
            continue
        if 'SUCCESS' not in out:
            logger.writelog("warn", "Errors encountered when executing init script")
            logger.writelog("warn", "Check local logs on {0}, log path {1}".format(
                sysconfig['oci']['wls']['nodes'][idx]['name'],
                "/var/log/wls_init.log"
            ))
        else:
            logger.writelog("info", "Init script executed successfully")
        
    # ATTACH BLOCK VOLUMES TO WLS NODES, RUN iscsi COMMANDS, FORMAT AND MOUNT
    logger.writelog("info", "Attaching block volumes to wls nodes")
    # attach volumes
    for idx in range(0, int(sysconfig['oci']['wls']['nodes_count'])):
        logger.writelog("info", "Attaching block volume {0} to node {1}".format(
            sysconfig['oci']['storage']['block_volumes'][idx]['name'],
            sysconfig['oci']['wls']['nodes'][idx]['name']
        ))
        success, ret = oci_manager.attach_block_volume(
            node_id=sysconfig['oci']['wls']['nodes'][idx]['id'],
            volume_id=sysconfig['oci']['storage']['block_volumes'][idx]['id']
        )
        if not success:
            logger.writelog("error", f"Could not attach block volume: {ret}")
            continue
        logger.writelog("info", "Block volume attached successfully")
        sysconfig['oci']['storage']['block_volumes'][idx]['attachment_id'] = ret.id
        sysconfig['oci']['storage']['block_volumes'][idx]['ip'] = ret.ipv4
        sysconfig['oci']['storage']['block_volumes'][idx]['iqn'] = ret.iqn
        save_sysconfig(sysconfig, sysconfig_file)
        # connect to node
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh.connect(username='opc',
                        hostname=sysconfig['oci']['wls']['nodes'][idx]['ip'],
                        key_filename=sysconfig['oci']['ssh_private_key'])
        except Exception as e:
            logger.writelog("error", f"Could not connect to instance {sysconfig['oci']['wls']['nodes'][idx]['name']}: {repr(e)}")
            continue
        # get current list of block devices so we can figure out what the new one is
        logger.writelog("debug", "Running sudo lsblk on remote host")
        stdin, stdout, stderr = ssh.exec_command('sudo lsblk')
        out = stdout.read().decode()
        err = stderr.read().decode()
        if err:
            logger.writelog("error", f"Could not run sudo lsblk on node: {err}")
            ssh.close()
            continue
        before = out.split("\n")
        # now run iscsi commands
        logger.writelog("info", f"Running iscsi commands on node {sysconfig['oci']['wls']['nodes'][idx]['name']}")
        cmd = "sudo iscsiadm -m node -o new -T {0} -p {1}:3260".format(
            sysconfig['oci']['storage']['block_volumes'][idx]['iqn'],
            sysconfig['oci']['storage']['block_volumes'][idx]['ip']
        )
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        if "New iSCSI node" not in stdout.read().decode():
            logger.writelog("error", "Failed running iscsi command")
            logger.writelog("debug", f"Command: {cmd}")
            logger.writelog("debug", f"Failure reason: {stderr.read().decode()}")
            ssh.close()
            continue
        cmd = "sudo iscsiadm -m node -o update -T {0} -n node.startup -v automatic".format(
            sysconfig['oci']['storage']['block_volumes'][idx]['iqn']
        )
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("error", "Failed running iscsi command")
            logger.writelog("debug", f"Command: {cmd}")
            logger.writelog("debug", f"Failure reason: {err}")
            ssh.close()
            continue
        cmd = "sudo iscsiadm -m node -T {0} -p {1}:3260 -l".format(
            sysconfig['oci']['storage']['block_volumes'][idx]['iqn'],
            sysconfig['oci']['storage']['block_volumes'][idx]['ip']
        )
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("error", "Failed running iscsi command")
            logger.writelog("debug", f"Command: {cmd}")
            logger.writelog("debug", f"Failure reason: {err}")
            ssh.close()
            continue
        # get list of devices after running iscsi commands
        stdin, stdout, stderr = ssh.exec_command('sudo lsblk')
        after = stdout.read().decode().split("\n")
        # sort out new volume
        new_vol = [vol for vol in after if vol not in before][0]
        new_vol = new_vol.split(" ")[0]
        # format new volume
        logger.writelog("info", "Formatting block volume")
        cmd = f"sudo mkfs.xfs -f /dev/{new_vol}"
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("error", f"Could not format volume: {err}")
            ssh.close()
            continue
        # get uuid in order to updated /etc/fstab
        logger.writelog("info", "Getting volume UUID")
        cmd = "sudo blkid"
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command("sudo blkid")
        err = stderr.read().decode()
        if err:
            logger.writelog("error", f"Could not get volume UUID: {err}")
            ssh.close()
            continue
        out = stdout.read().decode().split("\n")
        uuid = ""
        for vol in out:
            vol = vol.split(" ")
            if f"/dev/{new_vol}:" == vol[0]:
                uuid = vol[1]
                break
        if not uuid:
            logger.writelog("error", "Could not get volume uuid")
            ssh.close()
            continue
        # saving just the uuid in sysconfig and keeping 'UUID="<uuid value>"' in uuid variable 
        sysconfig['oci']['storage']['block_volumes'][idx]['uuid'] = uuid.split('"')[1]
        save_sysconfig(sysconfig, sysconfig_file)
        # need to remove quotes from uuid in order to update fstab
        uuid = uuid.replace('"', "")
        # create mountpoint
        logger.writelog("info", "Creating {0} mountpoint for block volume".format(
            sysconfig['prem']['wls']['mountpoints']['private']
        ))
        cmd = f"sudo mkdir {sysconfig['prem']['wls']['mountpoints']['private']}"
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("error", "Could not create {0} mountpoint: {1}".format(
                sysconfig['prem']['wls']['mountpoints']['private'],
                err
            ))
            ssh.close()
            continue
        # update /etc/fstab
        cmd = "echo '{0} {1} xfs defaults,_netdev,nofail 0 2' | sudo tee -a  /etc/fstab".format(
            uuid,
            sysconfig['prem']['wls']['mountpoints']['private']
        )
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("error", f"Could not update /etc/fstab: {err}")
            ssh.close()
            continue
        # mount block volume
        logger.writelog("info", "Mounting block volume")
        cmd = "sudo mount -a"
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("error", f"Failed mounting block volume: {err}")
            ssh.close()
            continue
        # check if volume monuted
        logger.writelog("info", "Checking if block volume succesfully mounted")
        cmd = "sudo df -h"
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("warn", f"Failed to check if block volume successfully mounted: {err}")
            ssh.close()
            continue
        out = stdout.read().decode().split("\n")
        mounted = False
        for line in out:
            if line.startswith(f"/dev/{new_vol}"):
                mounted = True
        if not mounted:
            logger.writelog("error", "Volume not mounted - check locally on node")
            ssh.close()
            continue
        logger.writelog("info", "Block volume succesfully mounted")
        logger.writelog("info", "Changing {0} mountpoint ownership to oracle:oinstall".format(
            sysconfig['prem']['wls']['mountpoints']['private']
        ))
        cmd = f"sudo chown oracle:oinstall {sysconfig['prem']['wls']['mountpoints']['private']}"
        logger.writelog("debug", f"Running {cmd} on remote host")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        err = stderr.read().decode()
        if err:
            logger.writelog("warn", "Failed changing mountpoint {0} ownership to oracle:oinstall: {1}".format(
                sysconfig['prem']['wls']['mountpoints']['private'],
                err
            ))
            logger.writelog("warn", "Check locally on node")
        else:
            logger.writelog("info", "Successfully changed {0} mountpoint ownership to oracle:oinstall".format(
                sysconfig['prem']['wls']['mountpoints']['private']
        ))
        ssh.close()


    # check init script execution status on OHS nodes
    for idx in range(0, int(sysconfig['oci']['ohs']['nodes_count'])):
        logger.writelog("info", f"Checking init script execution status on OHS node {sysconfig['oci']['ohs']['nodes'][idx]['name']}")
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh.connect(username='opc',
                        hostname=sysconfig['oci']['ohs']['nodes'][idx]['ip'],
                        key_filename=sysconfig['oci']['ssh_private_key'])
        except Exception as e:
            logger.writelog("error", f"Could not connect to instance {sysconfig['oci']['ohs']['nodes'][idx]['name']}: {str(e)}")
            continue
        cmd = 'tail -1 /var/log/ohs_init.log'
        logger.writelog("debug", f"Running {cmd} on {sysconfig['oci']['ohs']['nodes'][idx]['name']}")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        out = stdout.read().decode()
        err = stderr.read().decode()
        ssh.close()
        logger.writelog("debug", f"stdout: {out}")
        logger.writelog("debug", f"stderr: {err}")
        if err:
            logger.writelog("error", f"Could not check init script execution: {err}")
            logger.writelog("error", "Check local logs on {0}, log path {1}".format(
                sysconfig['oci']['ohs']['nodes'][idx]['name'],
                "/var/log/ohs_init.log"
            ))
            continue
        if 'SUCCESS' not in out:
            logger.writelog("warn", "Errors encountered when executing init script")
            logger.writelog("warn", "Check local logs on {0}, log path {1}".format(
                sysconfig['oci']['ohs']['nodes'][idx]['name'],
                "/var/log/ohs_init.log"
            ))
        else:
            logger.writelog("info", "Init script executed successfully")


    # CREATE HOST NAME ALIASES
    logger.writelog("info", "Preparing host name aliases")
    # create private view 
    logger.writelog("info", f"Creating private view {PRIVATE_VIEW_NAME}")
    success, ret = oci_manager.create_private_view(view_name=PRIVATE_VIEW_NAME)
    if not success:
        logger.writelog("error", "Could not create private view")
        logger.writelog("debug", f"Exception encountered: {ret}")
        sys.exit(1)
    sysconfig['oci']['dns'] = {}
    sysconfig['oci']['dns']['private_view'] = {}
    sysconfig['oci']['dns']['private_view']['name'] = ret.display_name
    sysconfig['oci']['dns']['private_view']['id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # create zone
    logger.writelog("info", f"Creating zone in private view")
    success, ret = oci_manager.create_zone(zone_name=sysconfig['prem']['network']['fqdn'], 
                                           view_id=sysconfig['oci']['dns']['private_view']['id'])
    if not success:
        logger.writelog("error", "Could not create zone")
        logger.writelog("debug", ret)
        sys.exit(1)
    sysconfig['oci']['dns']['zone'] = {}
    sysconfig['oci']['dns']['zone']['name'] = ret.name
    sysconfig['oci']['dns']['zone']['id'] = ret.id
    save_sysconfig(sysconfig, sysconfig_file)

    # create records in new zone with primary wls virtual hosts
    for idx in range(0, int(sysconfig['oci']['wls']['nodes_count'])):
        logger.writelog("info", "Adding record to zone: primary virtual host {0} with secondary IP {1}".format(
            sysconfig['prem']['wls']['listen_addresses'][idx],
            sysconfig['oci']['wls']['nodes'][idx]['ip']
        ))
        success, ret = oci_manager.add_ipv4_record_to_zone(
            zone_id=sysconfig['oci']['dns']['zone']['id'],
            zone_name=sysconfig['oci']['dns']['zone']['name'],
            host=sysconfig['prem']['wls']['listen_addresses'][idx],
            ip=sysconfig['oci']['wls']['nodes'][idx]['ip']
        )
        if not success:
            logger.writelog("info", "Failed adding record to zone")
            logger.writelog("debug", f"Exception encountered: {ret}")
            sys.exit(1)

    # attach view to VCN resolver
    logger.writelog("info", f"Attaching view to VCN {sysconfig['oci']['network']['vcn']['name']} resolver")
    success, ret = oci_manager.attach_view_to_dns_resolver(
        view_id=sysconfig['oci']['dns']['private_view']['id'],
        vcn_id=sysconfig['oci']['network']['vcn']['id']
    )
    if not success:
        logger.writelog("error", "Could not attach view to VCN resolver")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Successfully attached view to VCN resolver")

    # upload certificate to LBR
    # read files 
    with open(sysconfig['oci']['lbr']['public_certificate'], "r") as f:
        pub_cert = f.read()
    with open(sysconfig['oci']['lbr']['private_key'], "r") as f:
        private_key = f.read()
    ca_certificate = ""
    if sysconfig['oci']['lbr']['ca_certificate']:
        with open(sysconfig['oci']['lbr']['ca_certificate'], "r") as f:
            ca_certificate = f.read()
    logger.writelog("info", "Uploading certificate to LBR")
    success, ret = oci_manager.load_lbr_certificate(
        load_balancer_id=sysconfig['oci']['lbr']['id'],
        name=LBR_CERT_NAME,
        public_certificate=pub_cert,
        ca_certificate=ca_certificate,
        private_key=private_key
    )
    if not success:
        logger.writelog("error", "Failed uploading certificate to LBR")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Certificate uploaded to LBR")
    sysconfig['oci']['lbr']['cert_name'] = LBR_CERT_NAME

    if sysconfig['oci']['ohs']['console_port']:
        logger.writelog("info", "Creating LBR admin backend set")
        success, ret = oci_manager.lbr_create_backend_set(
            load_balancer_id=sysconfig['oci']['lbr']['id'],
            backend_set_name=LBR_ADMIN_BACKEND_SET_NAME,
            cookie_name=LBR_ADMIN_COOKIE_NAME,
            healthcheck_port=sysconfig['oci']['ohs']['console_port']
        )
        if not success:
            logger.writelog("error", "Could not create admin backend set")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Created admin backend set")
        sysconfig['oci']['lbr']['admin_backend_set'] = LBR_ADMIN_BACKEND_SET_NAME
        save_sysconfig(sysconfig, sysconfig_file)

    logger.writelog("info", "Creating LBR HTTP backend set")
    success, ret = oci_manager.lbr_create_backend_set(
        load_balancer_id=sysconfig['oci']['lbr']['id'],
        backend_set_name=LBR_HTTP_BACKEND_SET_NAME,
        cookie_name=LBR_HTTP_COOKIE_NAME,
        healthcheck_port=sysconfig['oci']['ohs']['http_port'],
        cookie_is_secure=True
    )
    if not success:
        logger.writelog("error", "Could not create HTTP backend set")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Created HTTP backend set")
    sysconfig['oci']['lbr']['http_backend_set'] = LBR_HTTP_BACKEND_SET_NAME
    save_sysconfig(sysconfig, sysconfig_file)

    logger.writelog("info", "Creating empty backend set")
    success, ret = oci_manager.lbr_create_backend_set(
        load_balancer_id=sysconfig['oci']['lbr']['id'],
        healthcheck_port=1,
        backend_set_name=LBR_EMPTY_BACKEND_SET_NAME
    )
    if not success:
        logger.writelog("error", "Could not create empty backend set")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Created empty backend set")
    sysconfig['oci']['lbr']['empty_backend_set'] = LBR_EMPTY_BACKEND_SET_NAME
    save_sysconfig(sysconfig, sysconfig_file)

    # Create internal backend set if required values are supplied in sysconfig csv input file
    if sysconfig['oci']['lbr']['virt_host_ohs_port'] \
        and sysconfig['oci']['lbr']['virt_host_hostname'] \
        and sysconfig['oci']['lbr']['virt_host_lbr_port']:
        logger.writelog("info", "Creating LBR internal backend set")
        success, ret = oci_manager.lbr_create_backend_set(
            load_balancer_id=sysconfig['oci']['lbr']['id'],
            backend_set_name=LBR_INTERNAL_BACKEND_SET_NAME,
            cookie_name=LBR_INTERNAL_COOKIE_NAME,
            healthcheck_port=sysconfig['oci']['lbr']['virt_host_ohs_port']
        )
        if not success:
            logger.writelog("error", "Could not create LBR internal backend set")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Created LBR internal backend set")
        sysconfig['oci']['lbr']['internal_backend_set'] = LBR_INTERNAL_BACKEND_SET_NAME
        save_sysconfig(sysconfig, sysconfig_file)

    # add LBR backends to backend sets
    # admin backend - if used
    if sysconfig['oci']['ohs']['console_port']:
        logger.writelog("info", "Adding backends to admin backend set")
        for node in sysconfig['oci']['ohs']['nodes']:
            logger.writelog("info", f"Adding backend {node['ip']} to admin backend set")
            success, ret = oci_manager.add_backend_to_set(
                lbr_id=sysconfig['oci']['lbr']['id'],
                backend_set_name=sysconfig['oci']['lbr']['admin_backend_set'],
                backend_ip=node['ip'],
                backend_port=sysconfig['oci']['ohs']['console_port']
            )
            if not success:
                logger.writelog("error", f"Failed adding backend {node['ip']} to admin backend set")
                logger.writelog("debug", ret)
                sys.exit(1)
            logger.writelog("info", f"Successfully added backend {node['ip']} to admin backend set")

    # http backend
    logger.writelog("info", "Adding backends to http backend set")
    for node in sysconfig['oci']['ohs']['nodes']:
        logger.writelog("info", f"Adding backend {node['ip']} to http backend set")
        success, ret = oci_manager.add_backend_to_set(
            lbr_id=sysconfig['oci']['lbr']['id'],
            backend_set_name=sysconfig['oci']['lbr']['http_backend_set'],
            backend_ip=node['ip'],
            backend_port=sysconfig['oci']['ohs']['http_port']
        )
        if not success:
            logger.writelog("error", f"Failed adding backend {node['ip']} to http backend set")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", f"Successfully added backend {node['ip']} to http backend set")

    if sysconfig['oci']['lbr']['virt_host_ohs_port'] \
        and sysconfig['oci']['lbr']['virt_host_hostname'] \
        and sysconfig['oci']['lbr']['virt_host_lbr_port']:
        logger.writelog("info", "Adding backends to internal backend set")
        for node in sysconfig['oci']['ohs']['nodes']:
            logger.writelog("info", f"Adding backend {node['ip']} to internal backend set")
            success, ret = oci_manager.add_backend_to_set(
                lbr_id=sysconfig['oci']['lbr']['id'],
                backend_set_name=sysconfig['oci']['lbr']['internal_backend_set'],
                backend_ip=node['ip'],
                backend_port=sysconfig['oci']['lbr']['virt_host_ohs_port']
            )
            if not success:
                logger.writelog("error", f"Failed adding backend {node['ip']} to internal backend set")
                logger.writelog("debug", ret)
                sys.exit(1)
            logger.writelog("info", f"Successfully added backend {node['ip']} to internal backend set")

    # create LBR virtual hostname
    logger.writelog("info", f"Creating LBR virtual hostname {sysconfig['oci']['lbr']['virtual_hostname_value']}")
    success, ret = oci_manager.create_lbr_virtual_hostname(
        lbr_id=sysconfig['oci']['lbr']['id'],
        hostname_name=LBR_HOSTNAME_NAME,
        hostname=sysconfig['oci']['lbr']['virtual_hostname_value']
    )
    if not success:
        logger.writelog("error", "Failed creating LBR virtual hostname")
        logger.writelog("debug", ret)
        sys.exit(1)
    sysconfig['oci']['lbr']['hostname_name'] = LBR_HOSTNAME_NAME
    save_sysconfig(sysconfig, sysconfig_file)

    # create LBR admin hostname - if used
    if sysconfig['oci']['lbr']['admin_hostname_value']:
        logger.writelog("info", f"Creating LBR admin hostname {sysconfig['oci']['lbr']['admin_hostname_value']}")
        success, ret = oci_manager.create_lbr_virtual_hostname(
            lbr_id=sysconfig['oci']['lbr']['id'],
            hostname_name=LBR_ADMIN_HOSTNAME_NAME,
            hostname=sysconfig['oci']['lbr']['admin_hostname_value']
        )
        if not success:
            logger.writelog("error", "Failed creating LBR admin hostname")
            logger.writelog("debug", ret)
            sys.exit(1)
        sysconfig['oci']['lbr']['admin_hostname_name'] = LBR_ADMIN_HOSTNAME_NAME
        save_sysconfig(sysconfig, sysconfig_file)

    # create LBR internal hostname if required values are supplied in sysconfig input csv file
    if sysconfig['oci']['lbr']['virt_host_ohs_port'] \
        and sysconfig['oci']['lbr']['virt_host_hostname'] \
        and sysconfig['oci']['lbr']['virt_host_lbr_port']:
        logger.writelog("info", f"Creating LBR internal hostname {sysconfig['oci']['lbr']['virt_host_hostname']}")
        success, ret = oci_manager.create_lbr_virtual_hostname(
            lbr_id=sysconfig['oci']['lbr']['id'],
            hostname_name=LBR_VIRT_HOST_HOSTNAME_NAME,
            hostname=sysconfig['oci']['lbr']['virt_host_hostname']
        )
        if not success:
            logger.writelog("error", "Failed creating LBR internal hostname")
            logger.writelog("debug", ret)
            sys.exit(1)
        sysconfig['oci']['lbr']['virt_hostname_name'] = LBR_VIRT_HOST_HOSTNAME_NAME
        save_sysconfig(sysconfig, sysconfig_file)

    # create rulesets
    logger.writelog("info", "Creating SSL headers ruleset")
    success, ret = oci_manager.lbr_create_ssl_headers_ruleset(
        lbr_id=sysconfig['oci']['lbr']['id'],
        ruleset_name=LBR_SSLHEADERS_RULE_SET
    )
    if not success:
        logger.writelog("error", "Failed creating SSL headers ruleset")
        logger.writelog("debug", ret)
        sys.exit(1)
    sysconfig['oci']['lbr']['ssl_headers_ruleset'] = LBR_SSLHEADERS_RULE_SET
    save_sysconfig(sysconfig, sysconfig_file)

    logger.writelog("info", "Creating HTTP redirect ruleset")
    success, ret = oci_manager.lbr_create_http_redirect_ruleset(
        lbr_id=sysconfig['oci']['lbr']['id'],
        ruleset_name=LBR_HTTP_REDIRECT_RULE_SET
    )
    if not success:
        logger.writelog("error", "Failed creating HTTP redirect ruleset")
        logger.writelog("debug", ret)
        sys.exit(1)
    sysconfig['oci']['lbr']['http_redirect_ruleset'] = LBR_HTTP_REDIRECT_RULE_SET
    save_sysconfig(sysconfig, sysconfig_file) 
    
    # create LBR listeners
    logger.writelog("info", "Creating listeners")
    # create admin listener - if used
    if sysconfig['oci']['lbr']['admin_port']:
        logger.writelog("info", "Creating admin listener")
        success, ret = oci_manager.lbr_create_listener(
            lbr_id=sysconfig['oci']['lbr']['id'],
            listener_name=LBR_ADMIN_LISTENER,
            backend_set_name=sysconfig['oci']['lbr']['admin_backend_set'],
            hostname_name=sysconfig['oci']['lbr']['admin_hostname_name'],
            port=sysconfig['oci']['lbr']['admin_port'],
        )
        if not success:
            logger.writelog("error", "Failed creating admin listener")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Created admin listener")

    logger.writelog("info", "Creating HTTPS listener")
    success, ret = oci_manager.lbr_create_listener(
        lbr_id=sysconfig['oci']['lbr']['id'],
        listener_name=LBR_HTTPS_LISTENER,
        backend_set_name=sysconfig['oci']['lbr']['http_backend_set'],
        hostname_name=sysconfig['oci']['lbr']['hostname_name'],
        port=sysconfig['oci']['lbr']['https_port'],
        use_ssl=True,
        certificate_name=sysconfig['oci']['lbr']['cert_name'],
        ruleset_names=[sysconfig['oci']['lbr']['ssl_headers_ruleset']]
    )
    if not success:
        logger.writelog("error", "Failed creating HTTPS listener")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Created HTTPS listener")

    logger.writelog("info", "Creating HTTP listener")
    success, ret = oci_manager.lbr_create_listener(
        lbr_id=sysconfig['oci']['lbr']['id'],
        listener_name=LBR_HTTP_LISTENER,
        backend_set_name=sysconfig['oci']['lbr']['empty_backend_set'],
        hostname_name=sysconfig['oci']['lbr']['hostname_name'],
        port=LBR_HTTP_PORT,
        ruleset_names=[sysconfig['oci']['lbr']['http_redirect_ruleset']]
    )
    if not success:
        logger.writelog("error", "Failed creating HTTP listener")
        logger.writelog("debug", ret)
        sys.exit(1)
    logger.writelog("info", "Created HTTP listener")

    # create internal listener if required values are supplied in sysconfig csv input file
    if sysconfig['oci']['lbr']['virt_host_ohs_port'] \
        and sysconfig['oci']['lbr']['virt_host_hostname'] \
        and sysconfig['oci']['lbr']['virt_host_lbr_port']:
        logger.writelog("info", "Creating internal listener")
        success, ret = oci_manager.lbr_create_listener(
            lbr_id=sysconfig['oci']['lbr']['id'],
            listener_name=LBR_VIRT_HOST_LISTENER,
            backend_set_name=sysconfig['oci']['lbr']['internal_backend_set'],
            hostname_name=sysconfig['oci']['lbr']['virt_hostname_name'],
            port=sysconfig['oci']['lbr']['virt_host_lbr_port']
        )
        if not success:
            logger.writelog("error", "Failed creating internal listener")
            logger.writelog("debug", ret)
            sys.exit(1)
        logger.writelog("info", "Created internal listener")

    logger.writelog("info", "All OCI resources provisioned")
    if Utils.confirm("Update OCI environment configuration file?"):
        logger.writelog("info", "Updating OCI environment configuration file")
        config = configparser.ConfigParser()
        config.read(CONSTANTS.OCI_ENV_FILE)
        # update oci ohs IP's
        config['OCI_ENV']['ohs_nodes'] = "\n".join(i['ip'] for i in sysconfig['oci']['ohs']['nodes'])
        # update oci wls IP's
        config['OCI_ENV']['wls_nodes'] = "\n".join(i['ip'] for i in sysconfig['oci']['wls']['nodes'])
        # update public key paths
        config['OCI_ENV']['ohs_ssh_key'] = sysconfig['oci']['ssh_private_key']
        config['OCI_ENV']['wls_ssh_key'] = sysconfig['oci']['ssh_private_key']
        with open(CONSTANTS.OCI_ENV_FILE, "w") as cfg_file:
            config.write(cfg_file)
    else:
        logger.writelog("info", "Will not update OCI environment configuration file")

if __name__ == "__main__":
    main()
