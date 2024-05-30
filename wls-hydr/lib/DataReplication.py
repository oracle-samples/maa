#!/usr/bin/python3

## DataReplication.py script version 1.0.
##
## Copyright (c) 2024 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##
### This script transfers data to and from a primary envirnoment to a secondary one
### This script should be executed in a bastion node with connectivity to both environments 
### Usage:
###
###      ./DataReplication.py <ACTION> [-i/--instance INSTANCE] [-d/--data DATA]
### Where:
###     ACTION:
###         Transfer actions to execute:
###             init:       Check and create staging environment   
###             pull:       Pull data from primary environment
###             push:       Push data to secondary environment
###             lifecycle:  Lifecycle operations (push and pull)
###             tnsnames    Retrieve tnsnames file from on-prem, 
###                           update values with OCI details and push to all OCI WLS nodes
###
###     INSTANCE:
###         Select what instance to replicate:
###             OHS:    Replicate only OHS data
###             WLS:    Replicate only WLS data
###         NOTE: Optional parameter; if not supplied, all instances are replicated
###
###     DATA:
###         Select which data to replicate:
###             products:       Replicate products data
###             private_config: Replicate private config data
###             shared_config:  Replicate shared config data (only applies to WLS instances)
###         NOTE: Optional parameter; if no DATA is supplied, all DATA will be replicated
###
### Examples:
###     To pull all data from WLS instances only:
###         ./DataReplication.py pull --instance WLS
###
###     To push products data to OHS instances only
###         ./DataReplication.py push --instance OHS --data products
###
###     To pull shared and private config data from WLS (shorthand used):
###         ./DataReplication.py pull -i WLS -d private_config -d shared_config
###
###     To push ALL data to ALL instances:
###         ./DataReplication.py push
###
###     To replicate tnsnames.ora in OCI with OCI values (scan address and service name)
###         ./DataReplication.py tnsnames
###

__version__= "1.0"
__author__ = "mibratu"

try:
    import os
    import sys
    sys.path.append(os.path.abspath(f"{os.path.dirname(os.path.realpath(__file__))}"))
    from Logger import Logger
    from Utils import Utils as UTILS
    from Utils import Constants as CONSTANTS
    from xml.etree import ElementTree as ET
    import errno
    import argparse
    import configparser
    import subprocess
    import shlex
    import pathlib
    import paramiko
    import time
    import io
except ImportError as e:
    raise ImportError(f"Failed to import module:\n{str(e)} \
        \nMake sure all required modules are installed before running this script")

# constants
BASEDIR = CONSTANTS.BASEDIR
EXTERNAL_CONFIG_FILE = CONSTANTS.EXTERNAL_CONFIG_FILE
INTERNAL_CONFIG_FILE = CONSTANTS.INTERNAL_CONFIG_FILE
OCI_ENV_FILE = CONSTANTS.OCI_ENV_FILE
PREM_ENV_FILE = CONSTANTS.PREM_ENV_FILE
LOG_FILE = f"{BASEDIR}/log/replication.log"
WLS_PRODUCTS_INFO = f"{BASEDIR}/lib/wls_products.info"
# config sections
DIRECTORIES = CONSTANTS.DIRECTORIES_CFG_TAG
OCI = CONSTANTS.OCI_CFG_TAG
PREM = CONSTANTS.PREM_CFG_TAG
OPTIONS = CONSTANTS.OPTIONS_CFG_TAG
TNS = CONSTANTS.TNS_TAG

CALLER = 'cli' if __name__ == '__main__' else 'import'

#TODO: work out a way to check which is primary and which is standby, placeholder for now:
if True:
    PRIMARY = PREM
    STANDBY = OCI
else:
    PRIMARY = OCI
    STANDBY = PREM


def myexit(code):
    if CALLER == 'cli':
        sys.exit(code)
    raise Exception(code)

def check_create_dir_structure(logger, config, wls_nodes, ohs_nodes, check_only):
    # work out what directories need to be created and check for them 
    for scope, path in config[DIRECTORIES].items():
        if scope.lower().startswith("stage"):
            if not os.path.isdir(path):
                if check_only:
                    logger.writelog("error", f"Directory {path} missing - possible data corruption - aborting")
                    return False
                else:
                    logger.writelog("info", f"Directory {path} missing - attempting to create")
                    try:
                        os.makedirs(path)
                    except Exception as e:
                        logger.writelog("error", f"Failed creating directory {path}")
                        logger.writelog("debug", str(e))
                        return False
                    logger.writelog("info", f"Created directory {path}")
    # now we need to create various directories based on the configuration we receive
    for ohs_node_count in range(1, ohs_nodes + 1):
        ohs_private_config_dir = f"{config[DIRECTORIES]['STAGE_OHS_PRIVATE_CONFIG_DIR']}/ohsnode{ohs_node_count}_private_config"
        if not os.path.isdir(ohs_private_config_dir):
            if check_only:
                logger.writelog("error", f"Directory {path} missing - possible data corruption - aborting")
                return False
            else:
                logger.writelog("info", f"Directory {ohs_private_config_dir} missing - attempting to create")
                try:
                    os.makedirs(ohs_private_config_dir)
                except Exception as e:
                    logger.writelog("error", f"Failed creating directory {ohs_private_config_dir}")
                    logger.writelog("debug", str(e))
                    return False
                logger.writelog("info", f"Created directory {ohs_private_config_dir}")
    for wls_node_count in range(1, wls_nodes + 1):
        wls_private_config_dir = f"{config[DIRECTORIES]['STAGE_WLS_PRIVATE_CONFIG_DIR']}/wlsnode{wls_node_count}_private_config"
        if not os.path.isdir(wls_private_config_dir):
            if check_only:
                logger.writelog("error", f"Directory {path} missing - possible data corruption - aborting")
                return False
            else:
                logger.writelog("info", f"Directory {wls_private_config_dir} missing - attempting to create")
                try:
                    os.makedirs(wls_private_config_dir)
                except Exception as e:
                    logger.writelog("error", f"Failed creating directory {wls_private_config_dir}")
                    logger.writelog("debug", str(e))
                    return False
                logger.writelog("info", f"Created directory {wls_private_config_dir}")
    return True


def check_connectivity(config_env):
    success = True
    errors = []
    ohs_nodes = config_env['ohs_nodes'].split("\n")
    for ohs_node in ohs_nodes:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh.connect(hostname=ohs_node, username=config_env['ohs_osuser'], key_filename=config_env['ohs_ssh_key'])
        except Exception as e:
            success = False
            errors.append("Failed connecting to host [{0}] using username [{1}] and key file [{2}]: {3}".format(
                ohs_node,
                config_env['ohs_osuser'],
                config_env['ohs_ssh_key'],
                str(e)
            ))
        ssh.close()
    wls_nodes = config_env['wls_nodes'].split("\n")
    for wls_node in wls_nodes:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            ssh.connect(hostname=wls_node, username=config_env['wls_osuser'], key_filename=config_env['wls_ssh_key'])
        except Exception as e:
            success = False
            errors.append("Failed connecting to host [{0}] using username [{1}] and key file [{2}]: {3}".format(
                wls_node,
                config_env['wls_osuser'],
                config_env['wls_ssh_key'],
                str(e)
            ))
        ssh.close()
    return success, errors


def transfer_data(transfer_type, use_delete, username, host, key_path, origin_path, destination_path, logger, retries, exclude_list=[]):
    delete = "--delete" if use_delete else ""
    exclude_list = " ".join([f'--exclude "{item}"' for item in exclude_list if item])
    username = username
    host = host
    if not origin_path.endswith("/"):
        origin_path += "/"
    if not destination_path.endswith("/"):
        destination_path += "/"
    if transfer_type == 'pull':
        origin = f"{username}@{host}:{origin_path}"
        destination = destination_path
    else:
        origin = origin_path
        destination = f"{username}@{host}:{destination_path}"      
    rsync_cmd = f'rsync -e "ssh -o StrictHostKeyChecking=no -i {key_path}" -avz {delete} --stats --modify-window=1 {exclude_list} {origin} {destination}'
    logger.writelog("debug", f"rsync command: {rsync_cmd}")
    logger.writelog("debug", f"rsync subprocess cmd:\n{shlex.split(rsync_cmd)}")
    with open(logger.log_file, "a+") as log:
        try:
            run = subprocess.Popen(shlex.split(rsync_cmd), stdout=log, stderr=log)
            run.communicate()
        except Exception as e:
            return False, f"rsync command encountered exception: {str(e)}"
    if run.returncode != 0:
        return False, "rsync command exited with non-zero return code"
    
    logger.writelog("info", "Data transferred - validating")
    rsync_diff_cmd = f'rsync -e "ssh -o StrictHostKeyChecking=no -i {key_path}" -niaHc --no-times {exclude_list} {origin} {destination} --modify-window=1'
    logger.writelog("debug", f"rsync diff command: {rsync_diff_cmd}")
    logger.writelog("debug", f"rsync diff subprocess cmd:\n{shlex.split(rsync_diff_cmd)}")
    run = subprocess.Popen(shlex.split(rsync_diff_cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    pending_files, err = run.communicate()
    if run.returncode != 0:
        return False, f"rsync diff command exited with non-zero return code: {err}"
    
    pending_files = pending_files.decode().splitlines()
    pending_files = [x.split()[1] for x in pending_files if x and "log" not in x and "DAT" not in x]

    logger.writelog("info", f"Number of differences found: {len(pending_files)}")
    if pending_files:
        still_diff = True
        if int(retries) > 0:
            retry_count = 0
            logger.writelog("info", "Attempting to resync differences")
            now = time.strftime("%Y_%m_%d_%H_%M_%S")
            diff_file = f"{BASEDIR}/log/replication_diffs_{now}.log"
            rsync_pending_cmd = f'rsync -e "ssh -o StrictHostKeyChecking=no -i {key_path}" --stats --modify-window=1 --files-from={diff_file} {origin} {destination}'
            logger.writelog("debug", f"rsync pending command: {rsync_pending_cmd}")
            logger.writelog("debug", f"rsync pending subprocess cmd:\n{shlex.split(rsync_pending_cmd)}")
            while still_diff:
                retry_count += 1
                if retry_count > int(retries):
                    return False, f"Max rsync retries [{retries}] exhausted and there are still differences between source and target\n" \
                                  f"List of differences can be found in {diff_file}"
                logger.writelog("info", f"Attempt #{retry_count}")
                with open(diff_file, "w") as f:
                    f.write("\n".join(pending_files))
                try:
                    # run = subprocess.Popen(shlex.split(rsync_pending_cmd), stdout=logger.log_file, stderr=logger.log_file)
                    run = subprocess.Popen(shlex.split(rsync_diff_cmd))
                    run.communicate()
                except Exception as e:
                    return False, f"rsync pending command encountered exception: {str(e)}"
                if run.returncode != 0:
                    return False, f"rsync pending command exited with non-zero return code"
                logger.writelog("info", "Checking if pending items have been synced")
                run = subprocess.Popen(shlex.split(rsync_diff_cmd), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                pending_files, err = run.communicate()
                if run.returncode != 0:
                    return False, f"rsync diff command exited with non-zero return code: {err}"
                pending_files = pending_files.decode().splitlines()
                pending_files = [x.split()[1] for x in pending_files if x and "log" not in x and "DAT" not in x]
                if pending_files:
                    logger.writelog("warn", "Differences remain")
                else:
                    logger.writelog("info", "Differences have been sorted - source and target directories are in sync")
                    if os.path.exists(diff_file):
                        os.remove(diff_file)
                    still_diff = False
        else:
            return False, "There are differences between source and target"
    else:
        logger.writelog("info", "Source and target directories are in sync")
        return True, ""
    return True, ""


def pull(logger, config, data, instance):
    pull_successful = True
    # pull wls data from primary
    # parse config for nodes 
    primary_wls_nodes = config[PRIMARY]['wls_nodes'].split("\n")
    primary_ohs_nodes = config[PRIMARY]['ohs_nodes'].split("\n")
    # pull wls if requested
    if any(ins in instance for ins in ['wls', 'all']):
        # pull wls products - 1 and 2 - if requested
        if any(dta in data for dta in ['products', 'all']):
            logger.writelog("info", f"Pulling WLS products1 from primary [{PRIMARY}]")
            pull_success, reason = transfer_data(
                transfer_type='pull',
                use_delete=config.getboolean(OPTIONS, 'delete'),
                username=config[PRIMARY]['wls_osuser'],
                host=primary_wls_nodes[0],
                key_path=config[PRIMARY]["wls_ssh_key"],
                origin_path=config[DIRECTORIES]['WLS_PRODUCTS'],
                destination_path=config[DIRECTORIES]['STAGE_WLS_PRODUCTS1'],
                logger=logger,
                retries=config[OPTIONS]['rsync_retries'],
                exclude_list=config[OPTIONS]['exclude_wls_products'].split("\n")
            )
            if not pull_success:
                logger.writelog("error", f"Pull failed: {reason}")
                logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                pull_successful = False
            logger.writelog("info", f"Pulling WLS products2 from primary [{PRIMARY}]")
            pull_success, reason = transfer_data(
                transfer_type='pull',
                use_delete=config.getboolean(OPTIONS, 'delete'),
                username=config[PRIMARY]['wls_osuser'],
                host=primary_wls_nodes[1],
                key_path=config[PRIMARY]["wls_ssh_key"],
                origin_path=config[DIRECTORIES]['WLS_PRODUCTS'],
                destination_path=config[DIRECTORIES]['STAGE_WLS_PRODUCTS2'],
                logger=logger,
                retries=config[OPTIONS]['rsync_retries'],
                exclude_list=config[OPTIONS]['exclude_wls_products'].split("\n")
            )
            if not pull_success:
                logger.writelog("error", f"Pull failed: {reason}")
                logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                pull_successful = False
        # pull wls private config from primary - if requested
        if any(dta in data for dta in ['private_config', 'all']):
            for index in range(len(primary_wls_nodes)):
                logger.writelog("info", f"Pulling WLS node {index + 1} private config from primary [{PRIMARY}]")
                pull_success, reason = transfer_data(
                    transfer_type='pull',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[PRIMARY]['wls_osuser'],
                    host=primary_wls_nodes[index],
                    key_path=config[PRIMARY]["wls_ssh_key"],
                    origin_path=config[DIRECTORIES]['WLS_PRIVATE_CONFIG_DIR'],
                    destination_path=f"{config[DIRECTORIES]['STAGE_WLS_PRIVATE_CONFIG_DIR']}/wlsnode{index + 1}_private_config",
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_private_config'].split("\n")
                )
                if not pull_success:
                    logger.writelog("error", f"Pull failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    pull_successful = False
        # pull wls shared config - if requested and if WLS_SHARED_CONFIG_DIR supplied in replication.properties 
        if any(dta in data for dta in ['shared_config', 'all']):
            if not config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR']:
                logger.writelog("info", "WLS_SHARED_CONFIG_DIR not supplied in replication.properties - shared config not used, will not pull")
            else:
                logger.writelog("info", f"Reading remote config.xml file [{config[DIRECTORIES]['WLS_CONFIG_PATH']}]")
                ssh_client = paramiko.SSHClient()
                ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                ssh_client.connect(username=config[PRIMARY]['wls_osuser'], hostname=primary_wls_nodes[0], key_filename=config[PRIMARY]["wls_ssh_key"])
                sftp_client = ssh_client.open_sftp()
                cfg_file = io.BytesIO()
                sftp_client.getfo(config[DIRECTORIES]['WLS_CONFIG_PATH'], cfg_file)
                cfg_file.seek(0)
                sftp_client.close()
                ssh_client.close()
                cfg_xml = ET.parse(cfg_file)
                root = cfg_xml.getroot()
                namespaces = {"xmlns" : "http://xmlns.oracle.com/weblogic/domain"}
                origin_apps_path = root.find("xmlns:app-deployment/[xmlns:name='em']/xmlns:source-path", namespaces).text
                origin_apps_path = pathlib.Path(origin_apps_path).parents[0].as_posix()
                logger.writelog("debug", f"Applications origin path: {origin_apps_path}")
                destination_apps_path = origin_apps_path.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug", f"Applications destination path: {destination_apps_path}")
                origin_domain_path = pathlib.Path(config[DIRECTORIES]['WLS_CONFIG_PATH']).parents[1].as_posix()
                logger.writelog("debug",f"Domain origin path: {origin_domain_path}")
                destination_domain_path = origin_domain_path.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug",f"Domain destination path: {destination_domain_path}")
                origin_dp_path = config[DIRECTORIES]['WLS_DP_DIR']
                logger.writelog("debug", f"Deployment plan directory origin path: {origin_dp_path}")
                destination_dp_path = origin_dp_path.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug", f"Deployment plan directory destination path: {destination_dp_path}")
                logger.writelog("info", f"Pulling WLS application from primary [{PRIMARY}]")
                if not os.path.isdir(destination_apps_path):
                    os.makedirs(destination_apps_path)
                pull_success, reason = transfer_data(
                    transfer_type='pull',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[PRIMARY]['wls_osuser'],
                    host=primary_wls_nodes[0],
                    key_path=config[PRIMARY]["wls_ssh_key"],
                    origin_path=origin_apps_path,
                    destination_path=destination_apps_path,
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                )
                if not pull_success:
                    logger.writelog("error", f"Pull failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    pull_successful = False
                logger.writelog("info", f"Pulling WLS domain from primary [{PRIMARY}]")
                if not os.path.isdir(destination_domain_path):
                    os.makedirs(destination_domain_path)
                pull_success, reason = transfer_data(
                    transfer_type='pull',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[PRIMARY]['wls_osuser'],
                    host=primary_wls_nodes[0],
                    key_path=config[PRIMARY]["wls_ssh_key"],
                    origin_path=origin_domain_path,
                    destination_path=destination_domain_path,
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                )
                if not pull_success:
                    logger.writelog("error", f"Pull failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    pull_successful = False
                logger.writelog("info", f"Pulling WLS deployment plan directory from primary [{PRIMARY}]")
                if not os.path.isdir(destination_dp_path):
                    os.makedirs(destination_dp_path)
                pull_success, reason = transfer_data(
                    transfer_type='pull',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[PRIMARY]['wls_osuser'],
                    host=primary_wls_nodes[0],
                    key_path=config[PRIMARY]["wls_ssh_key"],
                    origin_path=origin_dp_path,
                    destination_path=destination_dp_path,
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                )
                if not pull_success:
                    logger.writelog("error", f"Pull failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    pull_successful = False
                # pull additional directories (if any)
                additional_dirs = [ x.strip() for x in config[DIRECTORIES]['WLS_ADDITIONAL_SHARED_DIRS'].split("\n") if x]
                for dir in additional_dirs:
                    logger.writelog("info", f"Pulling additional WLS shared directory [{dir}]")
                    # create staging destination directory
                    stage_destination = f"{config[DIRECTORIES]['STAGE_WLS_SHARED_ADDITIONAL']}/{dir}"
                    if not os.path.isdir(stage_destination):
                        try:
                            logger.writelog("error", f"Creating directory {stage_destination}")
                            os.makedirs(stage_destination)
                        except Exception as e:
                            logger.writelog("error", f"Failed creating directory {stage_destination}")
                            logger.writelog("debug", str(e))
                            pull_successful = False
                            continue
                        logger.writelog("info", f"Created directory {stage_destination}")
                    pull_success, reason = transfer_data(
                        transfer_type='pull',
                        use_delete=config.getboolean(OPTIONS, 'delete'),
                        username=config[PRIMARY]['wls_osuser'],
                        host=primary_wls_nodes[0],
                        key_path=config[PRIMARY]["wls_ssh_key"],
                        origin_path=dir,
                        destination_path=stage_destination,
                        logger=logger,
                        retries=config[OPTIONS]['rsync_retries'],
                        exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                    )
                    if not pull_success:
                        logger.writelog("error", f"Pull failed: {reason}")
                        logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                        pull_successful = False

    # pull ohs products - if requested
    if any(ins in instance for ins in ['ohs', 'all']):
        if any(dta in data for dta in ['products', 'all']):
            logger.writelog("info", f"Pulling OHS products1 from primary [{PRIMARY}]")
            pull_success, reason = transfer_data(
                transfer_type='pull',
                use_delete=config.getboolean(OPTIONS, 'delete'),
                username=config[PRIMARY]['ohs_osuser'],
                host=primary_ohs_nodes[0],
                key_path=config[PRIMARY]["ohs_ssh_key"],
                origin_path=config[DIRECTORIES]['OHS_PRODUCTS'],
                destination_path=config[DIRECTORIES]['STAGE_OHS_PRODUCTS1'],
                logger=logger,
                retries=config[OPTIONS]['rsync_retries'],
                exclude_list=config[OPTIONS]['exclude_ohs_products'].split("\n")
            )
            if not pull_success:
                logger.writelog("error", f"Pull failed: {reason}")
                logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                pull_successful = False
            logger.writelog("info", f"Pulling OHS products2 from primary [{PRIMARY}]")
            pull_success, reason = transfer_data(
                transfer_type='pull',
                use_delete=config.getboolean(OPTIONS, 'delete'),
                username=config[PRIMARY]['ohs_osuser'],
                host=primary_ohs_nodes[1],
                key_path=config[PRIMARY]["ohs_ssh_key"],
                origin_path=config[DIRECTORIES]['OHS_PRODUCTS'],
                destination_path=config[DIRECTORIES]['STAGE_OHS_PRODUCTS2'],
                logger=logger,
                retries=config[OPTIONS]['rsync_retries'],
                exclude_list=config[OPTIONS]['exclude_ohs_products'].split("\n")
            )
            if not pull_success:
                logger.writelog("error", f"Pull failed: {reason}")
                logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                pull_successful = False
        # pull ohs private config - if requested
        if any(dta in data for dta in ['private_config', 'all']):
            for index in range(len(primary_ohs_nodes)):
                logger.writelog("info", f"Pulling OHS node {index + 1} private config from primary [{PRIMARY}]")
                pull_success, reason = transfer_data(
                    transfer_type='pull',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[PRIMARY]['ohs_osuser'],
                    host=primary_ohs_nodes[index],
                    key_path=config[PRIMARY]["ohs_ssh_key"],
                    origin_path=config[DIRECTORIES]['OHS_PRIVATE_CONFIG_DIR'],
                    destination_path=f"{config[DIRECTORIES]['STAGE_OHS_PRIVATE_CONFIG_DIR']}/ohsnode{index + 1}_private_config",
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_ohs_private_config'].split("\n")
                )
                if not pull_success:
                    logger.writelog("error", f"Pull failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    pull_successful = False
    return pull_successful


def push(logger, config, data, instance):
    push_successful = True
    # push wls data from primary
    # parse config for nodes 
    standby_wls_nodes = config[STANDBY]['wls_nodes'].split("\n")
    standby_ohs_nodes = config[STANDBY]['ohs_nodes'].split("\n")
    # push wls if requested
    if any(ins in instance for ins in ['wls', 'all']):
        # push wls products - 1 and 2 - if requested
        if any(dta in data for dta in ['products', 'all']):
            logger.writelog("info", f"Pushing wls products1 to standby [{STANDBY}]")
            push_success, reason = transfer_data(
                transfer_type='push',
                use_delete=config.getboolean(OPTIONS, 'delete'),
                username=config[STANDBY]['wls_osuser'],
                host=standby_wls_nodes[0],
                key_path=config[STANDBY]["wls_ssh_key"],
                origin_path=config[DIRECTORIES]['STAGE_WLS_PRODUCTS1'],
                destination_path=config[DIRECTORIES]['WLS_PRODUCTS'],
                logger=logger,
                retries=config[OPTIONS]['rsync_retries'],
                exclude_list=config[OPTIONS]['exclude_wls_products'].split("\n")
            )
            if not push_success:
                logger.writelog("error", f"Push failed: {reason}")
                logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                push_successful = False
            logger.writelog("info", f"Pushing wls products2 to standby [{STANDBY}]")
            push_success, reason = transfer_data(
                transfer_type='push',
                use_delete=config.getboolean(OPTIONS, 'delete'),
                username=config[STANDBY]['wls_osuser'],
                host=standby_wls_nodes[1],
                key_path=config[STANDBY]["wls_ssh_key"],
                origin_path=config[DIRECTORIES]['STAGE_WLS_PRODUCTS2'],
                destination_path=config[DIRECTORIES]['WLS_PRODUCTS'],
                logger=logger,
                retries=config[OPTIONS]['rsync_retries'],
                exclude_list=config[OPTIONS]['exclude_wls_products'].split("\n")
            )
            if not push_success:
                logger.writelog("error", f"Pull failed: {reason}")
                logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                push_successful = False
        # push wls private config to standby - if requested
        if any(dta in data for dta in ['private_config', 'all']):
            for index in range(len(standby_wls_nodes)):
                ssh_client = paramiko.SSHClient()
                ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                ssh_client.connect(username=config[STANDBY]['wls_osuser'], hostname=standby_wls_nodes[index], key_filename=config[STANDBY]["wls_ssh_key"])
                sftp_client = ssh_client.open_sftp()
                logger.writelog("debug", f"Checking destination directory exists: {config[DIRECTORIES]['WLS_PRIVATE_CONFIG_DIR']}")
                try:
                    sftp_client.stat(config[DIRECTORIES]['WLS_PRIVATE_CONFIG_DIR'])
                except IOError as e:
                    if e.errno == errno.ENOENT:
                        stdin, stdout, stderr = ssh_client.exec_command(f"mkdir -p {config[DIRECTORIES]['WLS_PRIVATE_CONFIG_DIR']}")
                        error = stderr.read().decode()
                        if error:
                            logger.writelog("error", f"Failed creating remote destination directory: {error}")
                            push_successful = False
                            continue
                    else:
                        logger.writelog("error", f"Cannot check remote destination directory exists: {str(e)}")
                        push_successful = False
                        continue
                sftp_client.close()
                ssh_client.close()
                logger.writelog("info", f"Pushing WLS node {index + 1} private config")
                push_success, reason = transfer_data(
                    transfer_type='push',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[STANDBY]['wls_osuser'],
                    host=standby_wls_nodes[index],
                    key_path=config[STANDBY]["wls_ssh_key"],
                    origin_path=f"{config[DIRECTORIES]['STAGE_WLS_PRIVATE_CONFIG_DIR']}/wlsnode{index + 1}_private_config",
                    destination_path=config[DIRECTORIES]['WLS_PRIVATE_CONFIG_DIR'],
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_private_config'].split("\n")
                )
                if not push_success:
                    logger.writelog("error", f"Push failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    push_successful = False
        # push wls shared config - if requested and if WLS_SHARED_CONFIG_DIR supplied in replication.properties 
        if any(dta in data for dta in ['shared_config', 'all']):
            if not config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR']:
                logger.writelog("info", "WLS_SHARED_CONFIG_DIR not supplied in replication.properties - shared config not used, will not push")
            else:
                local_cfg = config[DIRECTORIES]['WLS_CONFIG_PATH'].replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug", f"Reading local config.xml file [{local_cfg}]")
                cfg_xml = ET.parse(local_cfg)
                root = cfg_xml.getroot()
                namespaces = {"xmlns" : "http://xmlns.oracle.com/weblogic/domain"}
                destination_apps_path = root.find("xmlns:app-deployment/[xmlns:name='em']/xmlns:source-path", namespaces).text
                destination_apps_path = pathlib.Path(destination_apps_path).parents[0].as_posix()
                origin_apps_path = destination_apps_path.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug", f"Applications origin path: {origin_apps_path}")
                logger.writelog("debug", f"Applications destination path: {destination_apps_path}")
                destination_domain_path = pathlib.Path(config[DIRECTORIES]['WLS_CONFIG_PATH']).parents[1].as_posix()
                origin_domain_path = destination_domain_path.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug",f"Domain origin path: {origin_domain_path}")
                logger.writelog("debug",f"Domain destination path: {destination_domain_path}")
                destination_dp_path = config[DIRECTORIES]['WLS_DP_DIR']
                origin_dp_path = destination_dp_path.replace(config[DIRECTORIES]['WLS_SHARED_CONFIG_DIR'], config[DIRECTORIES]['STAGE_WLS_SHARED_CONFIG_DIR'])
                logger.writelog("debug", f"Deployment plan directory origin path: {origin_dp_path}")
                logger.writelog("debug", f"Deployment plan directory destination path: {destination_dp_path}")
                # transfer applications, domain an dp but make sure destination dirs exist first
                ssh_client = paramiko.SSHClient()
                ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                ssh_client.connect(username=config[STANDBY]['wls_osuser'], hostname=standby_wls_nodes[0], key_filename=config[STANDBY]["wls_ssh_key"])
                sftp_client = ssh_client.open_sftp()
                for destination in [destination_apps_path, destination_domain_path, destination_dp_path]:
                    logger.writelog("debug", f"Checking destination directory exists: {destination}")
                    try:
                        sftp_client.stat(destination)
                    except IOError as e:
                        if e.errno == errno.ENOENT:
                            stdin, stdout, stderr = ssh_client.exec_command(f"mkdir -p {destination}")
                            error = stderr.read().decode()
                            if error:
                                logger.writelog("error", f"Failed creating remote destination directory: {error}")
                                push_successful = False
                        else:
                            logger.writelog("error", f"Cannot check remote destination directory exists: {str(e)}")
                            push_successful = False
                sftp_client.close()
                ssh_client.close()
                logger.writelog("info", "Pushing WLS application to standby")
                push_success, reason = transfer_data(
                    transfer_type='push',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[STANDBY]['wls_osuser'],
                    host=standby_wls_nodes[0],
                    key_path=config[STANDBY]["wls_ssh_key"],
                    origin_path=origin_apps_path,
                    destination_path=destination_apps_path,
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                )
                if not push_success:
                    logger.writelog("error", f"Push failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    push_successful = False
                logger.writelog("info", "Pushing WLS domain to standby")
                push_success, reason = transfer_data(
                    transfer_type='push',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[STANDBY]['wls_osuser'],
                    host=standby_wls_nodes[0],
                    key_path=config[STANDBY]["wls_ssh_key"],
                    origin_path=origin_domain_path,
                    destination_path=destination_domain_path,
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                )
                if not push_success:
                    logger.writelog("error", f"Push failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    push_successful = False
                logger.writelog("info", "Pushing WLS deployment plan directory to standby")
                push_success, reason = transfer_data(
                    transfer_type='push',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[STANDBY]['wls_osuser'],
                    host=standby_wls_nodes[0],
                    key_path=config[STANDBY]["wls_ssh_key"],
                    origin_path=origin_dp_path,
                    destination_path=destination_dp_path,
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                )
                if not push_success:
                    logger.writelog("error", f"Push failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    push_successful = False
                # push additional dirs (if any)
                # open ssh and sftp conection to check destination directory exists
                ssh_client = paramiko.SSHClient()
                ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                ssh_client.connect(username=config[STANDBY]['wls_osuser'], hostname=standby_wls_nodes[0], key_filename=config[STANDBY]["wls_ssh_key"])
                sftp_client = ssh_client.open_sftp()
                additional_dirs = [ x.strip() for x in config[DIRECTORIES]['WLS_ADDITIONAL_SHARED_DIRS'].split("\n") if x]
                for dir in additional_dirs:
                    logger.writelog("info", f"Pushing additional WLS shared directory [{dir}]")
                    # check if directory exists in staging environment
                    stage_dir = f"{config[DIRECTORIES]['STAGE_WLS_SHARED_ADDITIONAL']}/{dir}"
                    if not os.path.isdir(stage_dir):
                        logger.writelog("error", f"Additional WLS shared directory [{stage_dir}] missing from staging environment - consider re-running pull")
                        push_successful = False
                        continue
                    # make sure destination directory exists
                    logger.writelog("debug", f"Checking destination directory exists: {dir}")
                    try:
                        sftp_client.stat(dir)
                    except IOError as e:
                        if e.errno == errno.ENOENT:
                            stdin, stdout, stderr = ssh_client.exec_command(f"mkdir -p {dir}")
                            error = stderr.read().decode()
                            if error:
                                logger.writelog("error", f"Failed creating remote destination directory: {error}")
                                push_successful = False
                                continue
                        else:
                            logger.writelog("error", f"Cannot check remote destination directory exists: {str(e)}")
                            push_successful = False
                            continue
                    push_success, reason = transfer_data(
                        transfer_type='push',
                        use_delete=config.getboolean(OPTIONS, 'delete'),
                        username=config[STANDBY]['wls_osuser'],
                        host=standby_wls_nodes[0],
                        key_path=config[STANDBY]["wls_ssh_key"],
                        origin_path=stage_dir,
                        destination_path=dir,
                        logger=logger,
                        retries=config[OPTIONS]['rsync_retries'],
                        exclude_list=config[OPTIONS]['exclude_wls_shared_config'].split("\n")
                    )
                    if not push_success:
                        logger.writelog("error", f"Push failed: {reason}")
                        logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                        push_successful = False
                sftp_client.close()
                ssh_client.close()

    # push ohs products - if requested
    if any(ins in instance for ins in ['ohs', 'all']):
        if any(dta in data for dta in ['products', 'all']):
            logger.writelog("info", "Pushing ohs products to standby")
            for index in range(len(standby_ohs_nodes)):
                logger.writelog("info", f"Pushing OHS node {index + 1} products")
                push_success, reason = transfer_data(
                    transfer_type='push',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[STANDBY]['ohs_osuser'],
                    host=standby_ohs_nodes[index],
                    key_path=config[STANDBY]["ohs_ssh_key"],
                    origin_path=config[DIRECTORIES][f'STAGE_OHS_PRODUCTS{index % 2 + 1}'],
                    destination_path=config[DIRECTORIES]['OHS_PRODUCTS'],
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_ohs_products'].split("\n")
                )
                if not push_success:
                    logger.writelog("error", f"Push failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    push_successful = False
        # push ohs private config - if requested
        if any(dta in data for dta in ['private_config', 'all']):
            for index in range(len(standby_ohs_nodes)):
                logger.writelog("info", f"Pushing OHS node {index + 1} private config")
                push_success, reason = transfer_data(
                    transfer_type='push',
                    use_delete=config.getboolean(OPTIONS, 'delete'),
                    username=config[STANDBY]['ohs_osuser'],
                    host=standby_ohs_nodes[index],
                    key_path=config[STANDBY]["ohs_ssh_key"],
                    origin_path=f"{config[DIRECTORIES]['STAGE_OHS_PRIVATE_CONFIG_DIR']}/ohsnode{index + 1}_private_config",
                    destination_path=config[DIRECTORIES]['OHS_PRIVATE_CONFIG_DIR'],
                    logger=logger,
                    retries=config[OPTIONS]['rsync_retries'],
                    exclude_list=config[OPTIONS]['exclude_ohs_private_config'].split("\n")
                )
                if not push_success:
                    logger.writelog("error", f"Pull failed: {reason}")
                    logger.writelog("error", f"Check log file {LOG_FILE} for further information")
                    push_successful = False
    return push_successful

def tnsnames(logger, config):
    logger.writelog("info", f"Retrieving tnsnames file from on-prem WLS node 1 [{config[TNS]['TNSNAMES_PATH']}]")
    # we're always pulling the file from on-prem wls node 1, update it with oci details and pushing it to all oci wls nodes
    prem_wls_nodes = config[PREM]['wls_nodes'].split("\n")
    oci_wls_nodes = config[OCI]['wls_nodes'].split("\n")
    ssh_client = paramiko.SSHClient()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_client.connect(username=config[PREM]['wls_osuser'], hostname=prem_wls_nodes[0], key_filename=config[PREM]["wls_ssh_key"])
    sftp_client = ssh_client.open_sftp()
    tns_file_name = os.path.basename(config[TNS]['TNSNAMES_PATH'])
    tns_file_dir = os.path.dirname(config[TNS]['TNSNAMES_PATH'])
    tns_file_stage_path = f"{config[DIRECTORIES]['STAGE_WLS_VAR']}/{tns_file_name}"
    # get the file from on-prem
    try:
        sftp_client.get(remotepath=config[TNS]['TNSNAMES_PATH'], localpath=tns_file_stage_path)
    except Exception as e:
        logger.writelog("error", f"Failed retrieving tnsnames file [{config[TNS]['TNSNAMES_PATH']}] from on-prem WLS node 1: {repr(e)}")
        return False
    sftp_client.close()
    ssh_client.close()
    # update file with oci details
    logger.writelog("info", f"Updating tns file with OCI details")
    updated_tns_content = ""
    with open(tns_file_stage_path, "r") as f:
        for line in f.readlines():
            line = line.replace(config[TNS]['PREM_SERVICE_NAME'], config[TNS]['OCI_SERVICE_NAME'])
            line = line.replace(config[TNS]['PREM_SCAN_ADDRESS'], config[TNS]['OCI_SCAN_ADDRESS'])
            updated_tns_content += line
    with open(tns_file_stage_path, "w") as f:
        f.write(updated_tns_content)
    # now push the file to all oci wls nodes
    for idx in range(len(oci_wls_nodes)):
        logger.writelog("info", f"Pushing updated tns file to OCI WLS node {idx +1}")
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_client.connect(username=config[OCI]['wls_osuser'], hostname=oci_wls_nodes[idx], key_filename=config[OCI]["wls_ssh_key"])
        sftp_client = ssh_client.open_sftp()
        # make sure the destination directory exist - create if not
        logger.writelog("info", f"Checking tns destination directory exists: {config[TNS]['TNSNAMES_PATH']}")
        try:
            sftp_client.stat(config[TNS]['TNSNAMES_PATH'])
        except IOError as e:
            if e.errno == errno.ENOENT:
                stdin, stdout, stderr = ssh_client.exec_command(f"mkdir -p {tns_file_dir}")
                error = stderr.read().decode()
                if error:
                    logger.writelog("error", f"Failed creating tns directory on OCI WLS node {idx + 1}: {error}")
                    return False
            else:
                logger.writelog("error", f"Cannot check if tns directory exists on OCI WLS node {idx +1}: {str(e)}")
                return False
        # push updated tns file
        try:
            sftp_client.put(localpath=tns_file_stage_path, remotepath=config[TNS]['TNSNAMES_PATH'])
        except Exception as e:
            logger.writelog("error", f"Failed pushing tsn file to OCI WLS node {idx +1}: {str(e)}")
            return False
        sftp_client.close()
        ssh_client.close()
        logger.writelog("info", f"Pushed updated tns file to OCI WLS node {idx +1}")
    return True

def run(log_level, action, data=None, instance=None, wls_nodes=None, ohs_nodes=None, **kwargs):
    log_level = 'DEBUG' if log_level else 'INFO'
    logger = Logger(LOG_FILE, log_level)
    logger.writelog("info", f"Data replication started - action set to {action}")
    logger.writelog("info", f"Primary environment set to {PRIMARY}")
    logger.writelog("info", "Reading configuration files")
    # check vars - defaults are 'all'
    if data is None:
        data = 'all'
    if instance is None:
        instance = 'all'
    # read all configuration files and update in-memory config
    # fail if any file is missing
    config = configparser.ConfigParser()
    # this will append any common values found between configs 
    for config_file in EXTERNAL_CONFIG_FILE, \
                       INTERNAL_CONFIG_FILE, \
                       OCI_ENV_FILE, \
                       PREM_ENV_FILE:
        try:
            tmp_cfg = configparser.RawConfigParser()
            with open(config_file, "r") as f:
                tmp_cfg.read_file(f)
                config = UTILS.update_config(config, tmp_cfg)
        except Exception as e:
            logger.writelog("error", f"Could not read configuration file [{config_file}]: {str(e)}")
            myexit(1)

    logger.writelog("info", "Validating configuration file")
    valid_config, errors = UTILS.validate_config(config, action, PRIMARY, STANDBY)
    if not valid_config:
        logger.writelog("error", "Errors found in configuration file:")
        for error in errors:
            logger.writelog("error", error)
        myexit(1)

    if action == 'init':
        logger.writelog("info", "Checking that all staging directories exist - creating if not")
        if wls_nodes is None:
            logger.writelog("error", "Missing value for WLS node count")
            myexit(1)
        if ohs_nodes is None:
            logger.writelog("error", "Missing value for OHS node count")
            myexit(1)
        if not check_create_dir_structure(logger, config, wls_nodes, ohs_nodes, check_only=False):
            logger.writelog("error", "Errors encountered checking/creating directories - exiting")
            myexit(1)

    elif action == 'pull':
        logger.writelog("info", "Checking that all staging directories exist - creating if not")
        ohs_nodes = len(config[PRIMARY]['ohs_nodes'].split("\n"))
        wls_nodes = len(config[PRIMARY]['wls_nodes'].split("\n"))
        if not check_create_dir_structure(logger, config, wls_nodes, ohs_nodes, check_only=False):
            logger.writelog("error", "Errors encountered checking/creating directories - exiting")
            myexit(1)
        # check connectivity
        logger.writelog("info", f"Checking connectivity to primary environment [{PRIMARY}]")
        conn_success, errors = check_connectivity(config[PRIMARY])
        if not conn_success:
            logger.writelog("error", f"Errors encountered while checking connectivity to primary [{PRIMARY}]:")
            for error in errors:
                logger.writelog("error", error)
            myexit(1)
        action_successfull = pull(logger, config, data, instance)

    elif action == 'push':
        logger.writelog("info", "Checking that all staging directories exist - exiting if not")
        ohs_nodes = len(config[STANDBY]['ohs_nodes'].split("\n"))
        wls_nodes = len(config[STANDBY]['wls_nodes'].split("\n"))
        if not check_create_dir_structure(logger, config, wls_nodes, ohs_nodes, check_only=True):
            logger.writelog("error", "Some or all staging directories missing - exiting")
            myexit(1)
        logger.writelog("info", f"Checking connectivity to standby environment [{STANDBY}]")
        conn_success, errors = check_connectivity(config[STANDBY])
        if not conn_success:
            logger.writelog("error", f"Errors encountered while checking connectivity to standby [{STANDBY}]:")
            for error in errors:
                logger.writelog("error", error)
            myexit(1)
        action_successfull = push(logger, config, data, instance)

    elif action == "tnsnames":
        logger.writelog("info", "Checking that all staging directories exist - creating if not")
        ohs_nodes = len(config[PREM]['ohs_nodes'].split("\n"))
        wls_nodes = len(config[PREM]['wls_nodes'].split("\n"))
        if wls_nodes is None:
            logger.writelog("error", "Missing value for WLS node count")
            myexit(1)
        if ohs_nodes is None:
            logger.writelog("error", "Missing value for OHS node count")
            myexit(1)
        if not check_create_dir_structure(logger, config, wls_nodes, ohs_nodes, check_only=False):
            logger.writelog("error", "Errors encountered checking/creating directories - exiting")
            myexit(1)
        logger.writelog("info", f"Checking connectivity to on-prem environment")
        conn_success, errors = check_connectivity(config[PREM])
        if not conn_success:
            logger.writelog("error", f"Errors encountered while checking connectivity to on-prem environment:")
            for error in errors:
                logger.writelog("error", error)
            myexit(1)
        logger.writelog("info", f"Checking connectivity to OCI environment")
        conn_success, errors = check_connectivity(config[OCI])
        if not conn_success:
            logger.writelog("error", f"Errors encountered while checking connectivity to OCI environment:")
            for error in errors:
                logger.writelog("error", error)
            myexit(1)
        action_successfull = tnsnames(logger, config)
    elif action == 'lifecycle':
        logger.writelog("info", "Feature not yet implemented")

    else:
        logger.writelog("error", f"Action [{action}] does not exist")
        myexit(1)

    if action_successfull:
        logger.writelog("info", f"Action [{action}] completed successfully")
    else:
        logger.writelog("warn", f"Action [{action}] completed with failures - check log file {LOG_FILE} for further information")
    


if __name__ == '__main__':
    arg_parser = argparse.ArgumentParser(description="Data replication utility", 
                                         formatter_class=argparse.RawTextHelpFormatter, 
                                         epilog=f"NOTE:\n \
Get action help by running the following:\n \
{os.path.basename(__file__)} ACTION [-h, --help]")
    
    arg_parser.add_argument("--debug", action="store_true",
                            dest="log_level",
                            help="set logging to debug")
    arg_parser.add_argument("-v", "--version", action='version', version=__version__)
    push_pull_parser = argparse.ArgumentParser(add_help=False)
    push_pull_parser.add_argument("-i", "--instance", choices=["ohs", "wls"],
                                metavar="INSTANCE",
                                action="append",
                                type=lambda val: val.lower(),
                                help="Select what instance to replicate:\nINSTANCE:\n \
OHS - replicate only OHS data\n \
WLS - replicate only WLS data\n")
    push_pull_parser.add_argument("-d", "--data", choices=["products", "shared_config", "private_config"],
                            metavar="DATA",
                            action="append",
                            type=lambda val: val.lower(),
                            help="Select which data to replicate:\nDATA:\n \
products       - replicate products data\n \
private_config - replicate private config data\n \
shared_config  - replicate shared config data - only applies to WLS")
    push_pull_parser.set_defaults(func=run)
    subparsers = arg_parser.add_subparsers(help="Action to execute",metavar="ACTION", dest='action')
    subparsers.required = True
    init_parser = subparsers.add_parser('init', 
                                          description="Check and create staging environment", 
                                          help="Check and create staging environment", 
                                          formatter_class=argparse.RawTextHelpFormatter)
    init_required = init_parser.add_argument_group(title="required arguments")
    init_required.add_argument("-w", "--wls-nodes", help="Number of WLS nodes", type=int, action="store", required=True)
    init_required.add_argument("-o", "--ohs-nodes", help="Number of OHS nodes", type=int, action="store", required=True)
    init_parser.set_defaults(func=run)
    pull_parser = subparsers.add_parser('pull', 
                                        description="Pull data from primary",
                                        help="Pull data from primary", 
                                        parents=[push_pull_parser], 
                                        formatter_class=argparse.RawTextHelpFormatter,
                                        epilog="NOTE:\n \
- If no INSTANCE is supplied, pull will be executed from all INSTANCEs\n \
- If no DATA is supplied, all DATA will be pulled")


    push_parser = subparsers.add_parser('push',
                                        description="Push data to secondary",
                                        help="Push data to secondary", 
                                        parents=[push_pull_parser], 
                                        formatter_class=argparse.RawTextHelpFormatter,
                                        epilog="NOTE:\n \
- If no INSTANCE is supplied, push will be executed on all INSTANCEs\n \
- If no DATA is supplied, all DATA will be pushed")
    
    lcycle_parser = subparsers.add_parser('lifecycle', help="Lifecycle operations")
    lcycle_parser.set_defaults(func=run)
    tnsnames_parser = subparsers.add_parser('tnsnames', help="Retrieve tnsnames file from on-prem, update values with OCI details and push to all OCI WLS nodes")
    tnsnames_parser.set_defaults(func=run)
    args = arg_parser.parse_args()
    kwargs = vars(args)
    args.func(**kwargs)
