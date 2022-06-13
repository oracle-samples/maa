# -*- coding: utf-8 -*-
"""
This is the top-level entry point for the MAA DR Setup (DRS) framework.

See the README.md file in this directory for details on how to configure and use this framework.

"""

__author__ = "Oracle Corp."
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """

# ====================================================================================================================
# Imports
# ====================================================================================================================

try:
    import os
except ImportError:
    print("ERROR: Could not import python's os module")
    os = None
    exit(-1)

try:
    import sys
except ImportError:
    print("ERROR: Could not import python's sys module")
    sys = None
    exit(-1)

try:
    import logging
except ImportError:
    print("ERROR: Could not import python's logging module")
    logging = None
    exit(-1)

try:
    import time
except ImportError:
    print("ERROR: Could not import python's time module")
    time = None
    exit(-1)

try:
    import argparse
except ImportError:
    print("ERROR: Could not import python's argparse module")
    argparse = None
    exit(-1)

try:
    import re
except ImportError:
    print("ERROR: Could not import python's re module")
    re = None
    exit(-1)

try:
    import fileinput
except ImportError:
    print("ERROR: Could not import python's fileinput module")
    fileinput = None
    exit(-1)

try:
    import copy
except ImportError:
    print("ERROR: Could not import python's copy module")
    copy = None
    exit(-1)

try:
    from datetime import datetime
except ImportError:
    print("ERROR: Could not import python's datetime module")
    datetime = None
    exit(-1)

try:
    import xmltodict
except ImportError:
    print("ERROR: Could not import python's xmldict module")
    xmltodict = None
    exit(-1)

try:
    import pprint
except ImportError:
    print("ERROR: Could not import python's pprint module")
    pprint = None
    exit(-1)

try:
    import getpass
except ImportError:
    print("ERROR: Could not import python's getpass module")
    getpass = None
    exit(-1)

try:
    from drs_config import DRS_CONFIG
except ImportError:
    print("ERROR: Could not import DRS drs_config module")
    DRS_CONFIG = None
    exit(-1)

try:
    from drs_const import DRS_CONSTANTS as CONSTANT
except ImportError:
    print("ERROR: Could not import DRS drs_const module")
    CONSTANT = None
    exit(-1)

try:
    from drs_lib import DRSLogger, DRSConfiguration, DRSHost, DRSDatabase, DRSWls, DRSUtil

    log_header = DRSUtil.log_header
except ImportError:
    print("ERROR: Could not import one or more DRS drs_lib modules")
    DRSLogger = None
    DRSConfiguration = None
    DRSHost = None
    DRSDatabase = None
    DRSWls = None
    DRSUtil = None
    exit(-1)

# ====================================================================================================================
# Global vars
# ====================================================================================================================

logger = None
parser = None
parser_args = None
user_config_dict = None


# ====================================================================================================================
# Local Methods
# ====================================================================================================================

def parse_arguments():
    """"
    Parse command line arguments

    """
    global parser
    global parser_args

    # set up parser
    parser = argparse.ArgumentParser(description='''
        This framework configures and tests DR between the SOA Primary and Standby sites.
        Specify either 
        the "--checks_only" or "-CH" to run the prerrequisite checks only, 
        or the "--config_dr" or "-C" option to only configure DR, 
        or the "--config_test_dr" or "-T" option to configure and then test DR after setup (the DR test involves 
        switching over the full SOA stack to the Standby site and then switching it back to the Primary site).

        The optional switch "--skip_checks" can be used to make the framework skip
        certain optional checks.  For example: checking if all the WLS components
        are running at the standby site.
        
        The optional switch "--do_not_start" cane used to make the framework skip the 
        start and validation of the standby WLS processes during the DR Setup"
        '''
        )

    parser.add_argument("-CH", "--checks_only", help="Run initialy checks only", action="store_true")
    parser.add_argument("-C", "--config_dr", help="Configure DR only", action="store_true")
    parser.add_argument("-T", "--config_test_dr", help="Configure and Test DR", action="store_true")
    parser.add_argument("-S", "--skip_checks", help="Skip certain optional checks", action="store_true")
    parser.add_argument("-N", "--do_not_start", help="Do not start standby WLS processes during the DR setup", action="store_true")

    # get arguments from the command line
    parser_args, unknown = parser.parse_known_args()

    if unknown:
        parser.print_help()
        print('\nERROR: Unknown option specified {}\n'.format(unknown))
        sys.exit(1)


def setup_logging():
    """"
    Set up logging

    """
    global logger

    # Set up handler for file and stdout
    log_filename = datetime.now().strftime(format(CONSTANT.DRS_LOGFILE_NAME))
    logfile_handler = logging.FileHandler(log_filename)
    logfile_handler.setLevel(CONSTANT.DRS_LOGFILE_LOG_LEVEL)  # DEBUG - Log verbosely to log file
    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setLevel(CONSTANT.DRS_STDOUT_LOG_LEVEL)  # INFO - More terse logging to stdout

    logging.basicConfig(
        level=CONSTANT.DRS_LOGGING_DEFAULT_LOG_LEVEL,
        format=CONSTANT.DRS_LOGFILE_STATEMENT_FORMAT,
        handlers=[logfile_handler, stdout_handler])

    logger = logging.getLogger("main")

    print("\nLog output will be sent to file [{}]\n".format(log_filename))

    # Change logfile permissions so only framework user can read/write file
    os.chmod(log_filename, 0o600)


def create_local_tempdir():
    """
    Create a local temp dir to use for storing temp files
    :return:
    """
    tempdir_name = CONSTANT.DRS_INTERNAL_TEMP_DIR
    if not os.path.isdir(tempdir_name):
        os.mkdir(tempdir_name)
        logger.info("Created local temp directory [{}]".format(tempdir_name))
    else:
        logger.info("Local temp directory [{}] already exists".format(tempdir_name))


def prompt_user_config_empty_values(dict_name, d):
    """
    Check the configuration dictionary for empty (uninitialized) config values and prompt the user to provide
    values for missing values.  For missing passwords, use 'getpass' to get password values.
    NOTE: This is a recursive function
    :param d: the config dict to check.
    :param dict_name: the name of the dictionary we are checking
    :return:
    """

    for k, v in d.items():
        if isinstance(v, dict):
            v = prompt_user_config_empty_values(k, v)
            d[k] = v
        else:
            if not v:
                logger.warning("\nATTENTION: Configuration value for [{}] was NOT found in user configuration file".
                               format(dict_name + '::' + k))

                # NOTE: RAC settings are left blank for a single instance setup, so don't prompt for them
                if 'rac_' in k:
                    logger.info("Ignoring blank value for [{}] because this must not be a RAC setup".
                                format(dict_name + '::' + k))
                    continue
                elif 'password' in k:
                    i = getpass.getpass('\nEnter password for configuration item [{}]: '.format(dict_name + '::' + k))
                    # Valid for password starting with # and  works with all the scripts. If used, the char $ needs to be escaped as \$ when provided
                    i = '"' + i + '"'
                else:
                    i = input('\nEnter value for configuration item [{}]: '.format(dict_name + '::' + k))
                d[k] = i
            else:
                d[k] = v
    return d


def read_user_yaml_configuration():
    """
    Reads and loads configuration from user configuration YAML file
    :return:
    """
    global user_config_dict
    # =============================================================================================================
    logger.info(" ")
    logger.info("==========  READING USER CONFIGURATION FILE  ==========")
    user_configuration = DRSConfiguration(CONSTANT.DRS_USER_CONFIG_FILE)

    # =============================================================================================================
    logger.info(" ")
    logger.info("===========  READING & CHECKING USER CONFIGURATION  ==========")

    user_config_dict = user_configuration.get_configuration_dict()

    user_config_dict = prompt_user_config_empty_values('user_config', user_config_dict)

    # FOR DEBUG ONLY... prints secure info
    print("Updated config dict is: \n[{}]".format(user_config_dict))

    # =============================================================================================================
    # logger.info(" ")
    # logger.info("===========  PRINTING CONFIGURATION TO LOGFILE  ==========")
    #  user_configuration.print_configuration_to_logfile()  -- DO NOT DO THIS!  IT TRASHES CONFIG PASSWORDS !!!
    # total_len = len(user_config_dict) + sum(len(v) for v in user_config_dict.items() if isinstance(v, dict))
    # logger.info("Printed [{}] configuration lines to logfile".format(total_len))
    # logger.info("Printed configuration to logfile")

    # =============================================================================================================

    logger.info(" ")
    logger.info("===========  INITIALIZING LOCAL CONFIGURATION  ==========")

    yaml_boolean_true = ['True', 'true', 'TRUE', 'Yes', 'yes', 'YES']
    yaml_boolean_false = ['False', 'false', 'FALSE', 'No', 'no', 'NO']

    # GENERAL
    CONFIG.GENERAL.ssh_user_name = user_config_dict['general']['ssh_user_name']
    CONFIG.GENERAL.ssh_key_file = user_config_dict['general']['ssh_key_file']
    CONFIG.GENERAL.ora_user_name = user_config_dict['general']['ora_user_name']

    # CONFIG.GENERAL.dataguard_use_private_ip = user_config_dict['general']['dataguard_use_private_ip']
    assert user_config_dict['general']['dataguard_use_private_ip'] in yaml_boolean_true \
        or user_config_dict['general']['dataguard_use_private_ip'] in yaml_boolean_false, \
        "dataguard_use_private_ip: %s is not valid, should be True or False" % \
        user_config_dict['general']['dataguard_use_private_ip']
    if user_config_dict['general']['dataguard_use_private_ip'] in yaml_boolean_true:
        CONFIG.GENERAL.dataguard_use_private_ip = True
    elif user_config_dict['general']['dataguard_use_private_ip'] in yaml_boolean_false:
        CONFIG.GENERAL.dataguard_use_private_ip = False

    CONFIG.GENERAL.uri_to_check = user_config_dict['general']['uri_to_check']

    assert user_config_dict['general']['dr_method'] in "RSYNC" \
           or user_config_dict['general']['dr_method'] in "DBFS", \
        "dr_method: %s is not valid, should be RSYNC or DBFS" % \
        user_config_dict['general']['dr_method']
    CONFIG.GENERAL.dr_method = user_config_dict['general']['dr_method']

    # DB PRIMARY
    CONFIG.DB_PRIM.host_ip = user_config_dict['db_prim']['host_ip']
    CONFIG.DB_PRIM.db_port = user_config_dict['db_prim']['port']
    CONFIG.DB_PRIM.sysdba_user_name = user_config_dict['db_prim']['sysdba_user_name']
    CONFIG.DB_PRIM.sysdba_password = user_config_dict['db_prim']['sysdba_password']
    CONFIG.DB_PRIM.pdb_name = user_config_dict['db_prim']['pdb_name']
    CONFIG.DB_PRIM.rac_scan_ip = user_config_dict['db_prim']['rac_scan_ip']  # NOTE: value can be empty if DB is not RAC

    # DB STANDBY
    CONFIG.DB_STBY.host_ip = user_config_dict['db_stby']['host_ip']
    CONFIG.DB_STBY.db_port = user_config_dict['db_stby']['port']
    CONFIG.DB_STBY.sysdba_user_name = user_config_dict['db_stby']['sysdba_user_name']
    CONFIG.DB_STBY.sysdba_password = user_config_dict['db_stby']['sysdba_password']
    CONFIG.DB_STBY.pdb_name = user_config_dict['db_stby']['pdb_name']

    # WLS PRIMARY
    CONFIG.WLS_PRIM.node_manager_host_ips = user_config_dict['wls_prim']['wls_ip_list']
    CONFIG.WLS_PRIM.wlsadm_host_ip = user_config_dict['wls_prim']['wls_ip_list'][0]
    CONFIG.WLS_PRIM.wlsadm_user_name = user_config_dict['wls_prim']['wlsadm_user_name']
    CONFIG.WLS_PRIM.wlsadm_password = user_config_dict['wls_prim']['wlsadm_password']
    CONFIG.WLS_PRIM.front_end_ip = user_config_dict['wls_prim']['front_end_ip']

    # WLS STANDBY
    CONFIG.WLS_STBY.node_manager_host_ips = user_config_dict['wls_stby']['wls_ip_list']
    CONFIG.WLS_STBY.wlsadm_host_ip = user_config_dict['wls_stby']['wls_ip_list'][0]
    CONFIG.WLS_STBY.wlsadm_user_name = user_config_dict['wls_stby']['wlsadm_user_name']
    CONFIG.WLS_STBY.wlsadm_password = user_config_dict['wls_stby']['wlsadm_password']
    CONFIG.WLS_STBY.front_end_ip = user_config_dict['wls_stby']['front_end_ip']

    logger.info("Local configuration is initialized")


def get_db_host_fqdn_and_ips(site_role):
    """
    Get FQDNs and Local IP addresses for DB host for the specified site

    :param site_role: THe site site_role for which to populate info ("PRIMARY" or "STANDBY")
    :return:
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        SITE_CONFIG = CONFIG.DB_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        SITE_CONFIG = CONFIG.DB_STBY
    else:
        raise Exception("Unknown site_role {}".format(site_role))

    logger.info(" ")
    logger.info("==========  GET DB HOST NAME & FQDN  ===========")

    host = DRSHost()
    host.connect_host(SITE_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    host_fqdn, local_ip, os_version = host.get_host_osinfo()
    # Make sure we didn't get empty values
    assert re.match('\S+\.\S+\.oraclevcn\.com', host_fqdn), "%s appears to be a malformed host FQDN" % host_fqdn
    assert re.match('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$', local_ip), "%s is not a valid IP address" % local_ip
    assert re.match('\d{1}\.\d{1,2}', os_version), "%s is not a valid OS version" % os_version

    SITE_CONFIG.host_fqdn = host_fqdn
    SITE_CONFIG.local_ip = local_ip
    SITE_CONFIG.os_version = os_version
    logger.info("DB host FQDN is [{}]".format(host_fqdn))
    logger.info("DB host local IP is [{}]".format(local_ip))
    logger.info("DB host OS version is [{}]".format(os_version))
    host.disconnect_host()

    # Extract DB host and domain name from FQDN
    parts = SITE_CONFIG.host_fqdn.split(".", 1)
    SITE_CONFIG.db_hostname = parts[0]
    SITE_CONFIG.db_host_domain = parts[1]
    logger.info("Extracted {} DB Hostname [{}]".format(site_role, parts[0]))
    logger.info("Extracted {} DB Domain Name [{}]".format(site_role, parts[1]))


def get_all_wls_host_fqdn_and_ips(site_role):
    """
    Get FQDNs and Local IP addresses for all WLS cluster hosts for the specified site

    :param site_role: THe site site_role for which to populate info ("PRIMARY" or "STANDBY")
    :return:
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        SITE_CONFIG = CONFIG.WLS_PRIM
        site_name = 'wls_prim'
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        SITE_CONFIG = CONFIG.WLS_STBY
        site_name = 'wls_stby'
    else:
        raise Exception("Unknown site_role {}".format(site_role))

    logger.info(" ")
    logger.info("==========  GET WLS HOST NAMES & FQDNS -- ALL {} CLUSTER NODES  ===========".format(site_role))

    # Walk the PRIMARY hosts list and get the info
    for host_ip in user_config_dict[site_name]['wls_ip_list']:
        host = DRSHost()

        host.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
        host_fqdn, local_ip, os_version = host.get_host_osinfo()
        # Make sure we didn't get empty values
        assert re.match('\S+\.\S+\.oraclevcn\.com', host_fqdn), "%s appears to be a malformed host FQDN" % host_fqdn
        assert re.match('\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', local_ip), "%s is not a valid IP address" % local_ip
        assert re.match('\d{1}\.\d{1,2}', os_version), "%s is not a valid OS version" % os_version

        SITE_CONFIG.cluster_node_fqdns.append(host_fqdn)
        SITE_CONFIG.cluster_node_local_ips.append(local_ip)
        SITE_CONFIG.cluster_node_public_ips.append(host_ip)
        SITE_CONFIG.cluster_node_os_versions.append(os_version)

        logger.info("Added host FQDN [{}] to our {} cluster FQDN list".format(host_fqdn, site_role))
        logger.info("Added host local IP [{}] to our {} cluster local IPs list".format(local_ip, site_role))
        logger.info("Added host public IP [{}] to our {} cluster public IPs list".format(host_ip, site_role))
        logger.info("Added OS version [{}] to our {} cluster OS versions list".format(os_version, site_role))

        host.disconnect_host()

    # Extract WLS admin host and domain names
    parts = SITE_CONFIG.cluster_node_fqdns[0].split(".", 1)
    SITE_CONFIG.wlsadm_hostname = parts[0]
    SITE_CONFIG.wlsadm_host_domain = parts[1]
    logger.info("Extracted {} Admin Server Hostname [{}]".format(parts[0], site_role))
    logger.info("Extracted {} Admin Server Domain Name [{}]".format(parts[1], site_role))


def patch_all_wls_etc_hosts(site_role):
    """
    Patch /etc/hosts on each WLS cluster node to create aliases for SOA DR

    :param site_role: THe site site_role for which to populate info ("PRIMARY" or "STANDBY")
    :return:
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        THIS_SITE_CONFIG = CONFIG.WLS_PRIM
        OTHER_SITE_CONFIG = CONFIG.WLS_STBY
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        THIS_SITE_CONFIG = CONFIG.WLS_STBY
        OTHER_SITE_CONFIG = CONFIG.WLS_PRIM
    else:
        raise Exception("Unknown site_role {}".format(site_role))

    logger.info(" ")
    logger.info("==========  PATCH /ETC/HOSTS -- ALL {} CLUSTER NODES  ===========".format(site_role))

    # Create a patching dictionary containing all entries to find and replace (or add) for this site
    # Patching dictionary entries use the format:
    #  {
    #     # regexp to use to find entry                 :  # new entry which will replace existing entry
    #     '^\s*10.0.0.1\s+hostA1.prim.com\s+hostA1.*$'  :  '10.0.0.1 hostA1.prim.com hostA1 hostB1.stby.com hostB1'
    #  }
    #
    patching_dict = dict()
    for i in range(len(THIS_SITE_CONFIG.cluster_node_local_ips)):
        this_host_name = THIS_SITE_CONFIG.cluster_node_fqdns[i].split('.', 1)[0]
        this_local_ip = THIS_SITE_CONFIG.cluster_node_local_ips[i]
        this_fqdn = THIS_SITE_CONFIG.cluster_node_fqdns[i]
        other_fqdn = OTHER_SITE_CONFIG.cluster_node_fqdns[i]
        other_host_name = OTHER_SITE_CONFIG.cluster_node_fqdns[i].split('.', 1)[0]
        regexp = r'^\s*{}\s+{}\s+{}.*$'.format(this_local_ip, this_fqdn, this_host_name)
        new_entry = '{}  {}  {}  {}  {}'.format(this_local_ip, this_fqdn, this_host_name, other_fqdn, other_host_name)
        patching_dict[regexp] = new_entry

    logger.debug("Created patching dictionary: \n{}".format(str(patching_dict)))

    etc_hosts_file = '/etc/hosts'
    for host_ip in THIS_SITE_CONFIG.cluster_node_public_ips:
        host = DRSHost()
        host.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

        logger.info("Begin processing /etc/hosts file for host {}.".format(host_ip))

        # 1) Fetch the remote hosts file; place in our temp working directory; and rename it
        logger.info("--- Step 1: Fetch remote /etc/hosts file")
        local_file_name = 'hosts' + '_' + host_ip + '_' + DRSUtil.generate_unique_filename()
        local_full_path = CONSTANT.DRS_INTERNAL_TEMP_DIR + '/' + local_file_name

        host.copy_remote_file_from_host(etc_hosts_file, local_full_path)

        # 2) Comment out all lines from the file that match regexps in our patching dictionary
        logger.info("--- Step 2: Generating entries for patching dictionary")
        for search_expr in patching_dict.keys():
            logger.debug("=== Searching for regexp::  {}".format(search_expr))
            regexp = re.compile(search_expr)
            for line in fileinput.input(local_full_path, inplace=True):
                logger.debug("=== read input line::  {}".format(line))
                if regexp.search(line):
                    logger.debug("*** regexp matches line !!!")
                    logger.debug("=== commented out line in file::  {}".format(line))
                    sys.stdout.write("### Commented out by DRS ###  " + line)
                else:
                    logger.debug("=== writing same line back to file::  {}".format(line))
                    sys.stdout.write(line)

            fileinput.close()  # WARNING!  FileInput has global scope. Must close() to reset.

        # 3) Append all lines from our patching dictionary to the file
        logger.info("--- Step 3: Append all lines from our patching dictionary to /etc/hosts file")
        f = open(local_full_path, "a")
        f.write("\n### BEGIN DRS SECTION -- lines below this added by DRS ### \n")
        logger.debug("Wrote: [### BEGIN DRS SECTION -- lines below this added by DRS ###] to file")
        for append_line in patching_dict.values():
            f.write(append_line + "\n")
            logger.debug("=== appended new line::  {}".format(append_line))
        f.write("### END DRS SECTION -- lines above this added by DRS ### \n")
        logger.debug("Wrote: [### END DRS SECTION -- lines above this added by DRS ###] to file")
        f.close()
        logger.info("Done processing /etc/hosts file for host {}. See debug log for details.".format(host_ip))

        # 4) Save a backup of the existing hosts file before we overwrite it
        logger.info("--- Step 4: Save a backup of the existing hosts file before we overwrite it")
        result = host.backup_remote_file_on_host(etc_hosts_file)
        logger.info("Backed up file [{}] on host [{}]".format(result.stdout.strip(), host_ip))

        # 5) Copy the edited /etc/hosts file back to the host
        #    NOTE: we do this by first writing it to /tmp on the host because fabric.Connection.put
        #    has no 'sudo' capability.  So we first 'put' the file to an allowed location (like /tmp)
        #    and then cp it using a remote 'sudo' command
        # TODO: Create a helper function for this type of sudo remote copy
        logger.info("--- Step 5: Copy the edited /etc/hosts file back to the host")
        dest_tmp_file = '/tmp/' + local_file_name
        host.copy_local_file_to_host(local_full_path, dest_tmp_file)
        logger.info("Copied edited file to [{}] on host [{}]".format(dest_tmp_file, host_ip))
        remote_cp_cmd = '/bin/cp -v --no-preserve=mode,ownership,timestamps'
        remote_sudo_cmd = CONSTANT.DRS_CMD_EXECUTE_SUDO_CMD_ONLY_FMT. \
            format(remote_cp_cmd + ' ' + dest_tmp_file + ' /etc/hosts')
        host.execute_host_cmd_sudo_root(remote_sudo_cmd)

        # TODO: Do we really need this?
        """
        # 6) Convert CR-LF to LF (dos2unix) for remotely copied /etc/hosts file
        logger.info("Process CR+LF for /etc/hosts file on host {}".format(host_ip))
        remote_dos2unix_cmd = CONSTANT.DRS_CMD_PERL_DOS2UNIX.format('/etc/hosts')
        remote_sudo_cmd = CONSTANT.DRS_CMD_EXECUTE_SUDO_CMD_ONLY_FMT.format(remote_dos2unix_cmd)
        host.execute_host_cmd_sudo_root(remote_sudo_cmd)
        """

        # 6) Remove the hosts file we temporarily stored locally in /tmp
        logger.info("--- Step 6: Remove the hosts file we temporarily stored locally in /tmp on remote host")
        host.delete_remote_file_from_host(dest_tmp_file, host.user_name)


def patch_all_wls_etc_oci_hostname_conf(site_role):
    """
    Patch /etc/oci-hostname.conf on each WLS cluster node on specified site
    We add "PRESERVE_HOSTINFO=2" or "PRESERVE_HOSTINFO=3" to the conf file so our config
    changes to /etc/hosts are preserved

    :param site_role: THe site site_role for which to populate info ("PRIMARY" or "STANDBY")
    :return:
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        SITE_CONFIG = CONFIG.WLS_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        SITE_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown site_role {}".format(site_role))

    logger.info(" ")
    logger.info("==========  PATCH /ETC/OCI-HOSTNAME.CONF -- ALL {} CLUSTER NODES  ===========".format(site_role))

    config_file = '/etc/oci-hostname.conf'
    for host_ip, os_version in zip(SITE_CONFIG.cluster_node_public_ips, SITE_CONFIG.cluster_node_os_versions):
        host = DRSHost()
        host.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
        ph_value = '3'

        logger.info("Begin processing {} file for host {}.".format(config_file, host_ip))
        logger.info("Will set PRESERVE_HOSTINFO={} since OS version is {}".format(ph_value, os_version))

        # 1) Fetch the remote file; place in our temp working directory; and rename it
        logger.info("--- Step 1: Fetch remote {} file".format(config_file))
        local_file_name = 'oci-hostname.conf' + '_' + host_ip + '_' + DRSUtil.generate_unique_filename()
        local_full_path = CONSTANT.DRS_INTERNAL_TEMP_DIR + '/' + local_file_name

        host.copy_remote_file_from_host(config_file, local_full_path)

        # 2) Comment out all lines from the file that match our regexp
        logger.info("--- Step 2: Patching file")
        search_expr = r'^PRESERVE_HOSTINFO[ ]*='
        logger.debug("=== Searching for regexp::  {}".format(search_expr))
        regexp = re.compile(search_expr)
        for line in fileinput.input(local_full_path, inplace=True):
            logger.debug("=== read input line::  {}".format(line))
            if regexp.search(line):
                logger.debug("*** regexp matches line !!!")
                logger.debug("=== commented out line in file::  {}".format(line))
                sys.stdout.write("### Commented out by DRS ###  " + line)
            else:
                logger.debug("=== writing same line back to file::  {}".format(line))
                sys.stdout.write(line)

        fileinput.close()  # WARNING!  FileInput has global scope. Must close() to reset.

        # 3) Append 'PRESERVE_HOSTINFO=<ph_value>' to the oci-hostname.conf file
        logger.info("--- Step 3: Append 'PRESERVE_HOSTINFO={}' to {} file".format(ph_value, config_file))
        f = open(local_full_path, "a")
        f.write("\n### BEGIN DRS SECTION -- lines below this added by DRS ### \n")
        logger.debug("Wrote: [#### BEGIN DRS SECTION -- lines below this added by DRS ####] to file")
        append_line = 'PRESERVE_HOSTINFO={}'.format(ph_value)
        f.write(append_line + "\n")
        logger.debug("=== appended new line::  {}".format(append_line))
        f.write("### END DRS SECTION -- lines above this added by DRS ### \n")
        logger.debug("Wrote: [#### END DRS SECTION -- lines above this added by DRS ####] to file")
        f.close()
        logger.info("Done processing {} file for host {}. See debug log for details.".format(config_file, host_ip))

        # 4) Save a backup of the existing config file before we overwrite it
        logger.info("--- Step 4: Save a backup of the existing hosts file before we overwrite it")
        result = host.backup_remote_file_on_host(config_file)
        logger.info("Backed up file [{}] on host [{}]".format(result.stdout.strip(), host_ip))

        # 5) Copy the edited file back to the host
        #    NOTE: we do this by first writing it to /tmp on the host because fabric.Connection.put
        #    has no 'sudo' capability.  So we first 'put' the file to an allowed location (like /tmp)
        #    and then cp it using a remote 'sudo' command
        # TODO: Create a helper function for this type of sudo remote copy
        logger.info("--- Step 5: Copy the edited file back to the host")
        dest_tmp_file = '/tmp/' + local_file_name
        host.copy_local_file_to_host(local_full_path, dest_tmp_file)
        logger.info("Copied edited file to [{}] on host [{}]".format(dest_tmp_file, host_ip))
        remote_cp_cmd = '/bin/cp -v --no-preserve=mode,ownership,timestamps'
        remote_sudo_cmd = CONSTANT.DRS_CMD_EXECUTE_SUDO_CMD_ONLY_FMT. \
            format(remote_cp_cmd + ' ' + dest_tmp_file + ' /etc/oci-hostname.conf')
        host.execute_host_cmd_sudo_root(remote_sudo_cmd)

        # 6) Remove the temp file we temporarily stored on host in /tmp
        logger.info("--- Step 6: Remove the file we temporarily stored locally in /tmp on remote host")
        host.delete_remote_file_from_host(dest_tmp_file, host.user_name)


def get_wls_domain_configuration(role, domain_home):
    """
    Get the WLS domain configuration file from the specified domain home and parse
    it's contents.  Then, load our local config with those parsed contents.

    :param role: THe site role for which to populate info ("PRIMARY" or "STANDBY")
    :param domain_home: The domain home for

    :return:
    """

    if role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        SITE_CONFIG = CONFIG.WLS_PRIM
    elif role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        SITE_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown role {}".format(role))

    logger.info(" ")
    logger.info("==========  GET WLS DOMAIN CONFIGURATION FILE -- {} SITE   ===========".format(role))

    prim_wls = DRSWls()
    prim_wls.connect_host(SITE_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    domain_config_file = domain_home + CONSTANT.DRS_WLS_CONFIG_FILE_RELATIVE_PATH_NAME
    domain_config_file_contents = prim_wls.get_wls_domain_config_file_contents(domain_config_file,
                                                                               CONFIG.GENERAL.ora_user_name)

    # Save the domain info file contents to our local temp dir in case we need it again.
    # Reason: At some point the standby domain info will get trashed during DR wiring.  If DRS setup fails after this
    # point, and we re-run it to try and setup DR again, there is no standby domain info file to get.  In that case,
    # we will need to rely on this local saved copy.
    local_file_name = 'wls_domain_config' + '_' + role + '_' + SITE_CONFIG.wlsadm_host_ip + '.xml'
    local_full_path = CONSTANT.DRS_INTERNAL_TEMP_DIR + '/' + local_file_name
    fh = open(local_full_path, mode='wt')
    fh.write(domain_config_file_contents)
    fh.flush()
    fh.close()

    # Parse the XML file contents
    xml_config_dict = xmltodict.parse(domain_config_file_contents)

    # pprint.pprint(xml_config_dict)

    SITE_CONFIG.cluster_size = len(xml_config_dict['domain']['machine'])

    # pprint.pprint(xml_server_list)

    logger.info(" ")
    logger.info("==========  GET ADMIN SERVER CONFIG FROM CONFIG FILE -- {} SITE   ===========".format(role))

    # V16 - remove dependency from the adminserver suffix
    # to get the admin server as the first node of the list (not used)
    #xml_server_list = xml_config_dict['domain']['server']
    #SITE_CONFIG.wlsadm_server_name = xml_server_list[0]['name']
    #try:
    #    SITE_CONFIG.wlsadm_listen_port = xml_server_list[0]['listen-port']
    #except KeyError:
    #    SITE_CONFIG.wlsadm_listen_port = CONSTANT.DRS_WLS_ADMIN_DEFAULT_LISTEN_PORT
    #logger.info("Admin server name is [{}]".format(SITE_CONFIG.wlsadm_server_name))
    #logger.info("Admin server listen port is [{}]".format(SITE_CONFIG.wlsadm_listen_port))
    ######################################

    # V16 we get the admin server from the em target
    #############################################
    xml_server_list = xml_config_dict['domain']['server']
    deployment_list = xml_config_dict['domain']['app-deployment']
    # to get the admin server name
    found = False
    for deployment in deployment_list:
        if  deployment['name'] == "em":
            SITE_CONFIG.wlsadm_server_name = deployment['target']
            found = True
            break
        else:
            # only executed if we do NOT break out of inner for loop
            continue
    if not found:
        raise Exception("ERROR: Could not find em deployment name in domain config file")

    # Now we have the admin server name, get the port
    ################################################
    found = False
    for xml_server in xml_server_list:
        if SITE_CONFIG.wlsadm_server_name == xml_server['name']:
            # we've found the admin server entry now check for a listen-port
            try:
                SITE_CONFIG.wlsadm_listen_port = xml_server['listen-port']
            except KeyError:
                SITE_CONFIG.wlsadm_listen_port = CONSTANT.DRS_WLS_ADMIN_DEFAULT_LISTEN_PORT
            logger.info("Admin server name is [{}]".format(SITE_CONFIG.wlsadm_server_name))
            logger.info("Admin server listen port is [{}]".format(SITE_CONFIG.wlsadm_listen_port))
            found = True
            break
        else:
            # only executed if we do NOT break out of inner for loop
            continue

    if not found:
        raise Exception("ERROR: Could not find admin server name in domain config file")

    logger.info(" ")
    logger.info("==========  GET NODE MANAGER CONFIG FROM CONFIG FILE -- {} SITE   ===========".format(role))
    machine_list = xml_config_dict['domain']['machine']
    machine_count = len(machine_list)
    found = False
    for machine in machine_list:
        nm = machine['node-manager']
        parts = nm['listen-address'].split('.', 1)
        nm_hostname = parts[0]
        if nm_hostname == SITE_CONFIG.wlsadm_hostname:
            # we've found the NM entry for the admin host
            SITE_CONFIG.wlsadm_nm_hostname = nm_hostname
            SITE_CONFIG.wlsadm_nm_port = nm['listen-port']
            SITE_CONFIG.wlsadm_nm_type = nm['nm-type']
            logger.info("NM host name is [{}]".format(SITE_CONFIG.wlsadm_nm_hostname))
            logger.info("NM listen port is [{}]".format(SITE_CONFIG.wlsadm_nm_port))
            logger.info("NM connection type is [{}]".format(SITE_CONFIG.wlsadm_nm_type))
            found = True
            break

    if not found:
        raise Exception("ERROR: Could not find node manager configuration in domain config file")
    ###########
    logger.info(" ")
    logger.info("==========  GET MANAGED SERVER CONFIG FROM CONFIG FILE -- {} SITE   ===========".format(role))
    xml_server_list = xml_config_dict['domain']['server']
    # Fix managed servers not correctly ordered
    SITE_CONFIG.managed_server_names = ["None"] * SITE_CONFIG.cluster_size
    SITE_CONFIG.managed_server_hosts = ["None"] * SITE_CONFIG.cluster_size
    # This needs to be improved. As it is now, this breaks the idempotency because it looks for the stby manager using
    # the standby fqdn names, and this does not work if DRS as been run previously and the config has been already
    # copied from primary
    for xml_server in xml_server_list:
        if SITE_CONFIG.wlsadm_server_name not in xml_server['name']:
            # this must be a managed server entry
            managed_server_fqdn = xml_server['listen-address']
            index = SITE_CONFIG.cluster_node_fqdns.index(managed_server_fqdn)
            # SITE_CONFIG.managed_server_names.insert(index, xml_server['name'])
            # SITE_CONFIG.managed_server_hosts.insert(index, xml_server['listen-address'].split('.', 1)[0])
            # Fix managed servers not correctly ordered
            SITE_CONFIG.managed_server_names[index] = xml_server['name']
            SITE_CONFIG.managed_server_hosts[index] = xml_server['listen-address'].split('.', 1)[0]
            logger.info("Managed server [{}] is deployed on host [{}]".
                        format(SITE_CONFIG.managed_server_names[index], SITE_CONFIG.managed_server_hosts[index]))

    # Make sure here that the number of parsed nodes (from config) and those specified by the user in the
    # YAML config match each other
    if len(SITE_CONFIG.node_manager_host_ips) != machine_count:
        raise Exception(
            "ERROR: Number of user-specified cluster nodes [{}] does not match machine count [{}] "
            "obtained from WLS config file".format(len(SITE_CONFIG.node_manager_host_ips), machine_count))

    print("Successfully parsed WLS XML configuration file. Machine count [{}] matches".format(machine_count))

    # v13 Get the  configured frontend name
    # we will use later to check that primary fronted is resolvable from standby
    try:
        cluster_frontend=xml_config_dict['domain']['cluster']['frontend-host']
        logger.info("Cluster frontend-host name is [{}]".format(cluster_frontend))
        SITE_CONFIG.cluster_frontend_host=cluster_frontend
    except Exception as e:
        # It should be configured (needed for soa) but we catch the error in case it is not defined
        logger.warning("WARNING: Cluster frontend hostname is NOT configured!")
        logger.warning("WARNING: Continuing with DR setup, but it should be configured with a virtual frontend name")
        SITE_CONFIG.cluster_frontend_host="no-frontend"


def get_wls_domain_name_and_home(role):
    """
    Get WLS Domain name and home for specified site

    :param role: THe site role for which to populate info ("PRIMARY" or "STANDBY")
    :return:
    """
    if role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        SITE_CONFIG = CONFIG.WLS_PRIM
    elif role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        SITE_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown role {}".format(role))

    logger.info(" ")
    logger.info("==========  GET WLS DOMAIN NAME & HOME FROM {} WLS ADMIN SERVER HOST   ===========".format(role))
    wls_admin = DRSWls()
    wls_admin.connect_host(SITE_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    domain_home = wls_admin.get_wls_domain_home(CONFIG.GENERAL.ora_user_name)
    domain_name = os.path.basename(domain_home)
    wls_admin.disconnect_host()

    logger.info("WLS domain home at {} site is [{}]".format(role, domain_home))
    logger.info("WLS domain name at {} site is [{}]".format(role, domain_name))

    SITE_CONFIG.domain_home = domain_home
    SITE_CONFIG.domain_name = domain_name


def get_wls_home(role):
    """
    Get WLS home for specified site

    :param role: THe site role for which to populate info ("PRIMARY" or "STANDBY")
    :return:
    """

    if role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        SITE_CONFIG = CONFIG.WLS_PRIM
    elif role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        SITE_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown role {}".format(role))

    logger.info(" ")
    logger.info("==========  GET WLS HOME -- {} SITE  ===========".format(role))

    wls_admin = DRSWls()
    wls_admin.connect_host(SITE_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    wls_home = wls_admin.get_wls_home(CONFIG.GENERAL.ora_user_name)
    wl_home = os.path.dirname(wls_home)
    mw_home = os.path.dirname(wl_home)

    SITE_CONFIG.wls_home = wls_home
    SITE_CONFIG.wl_home = wl_home
    SITE_CONFIG.mw_home = mw_home

    logger.info(" WebLogic Server Home ($WLS_HOME) at {} site is [{}]".format(role, wls_home))
    logger.info(" WebLogic Home ($WL_HOME) at {} site is [{}]".format(role, wl_home))
    logger.info(" Middleware Home ($MW_HOME) at {} site is [{}]".format(role, mw_home))


def verify_internal_configuration():
    """
    Check consistency of configuration.
    This should only be called after the configuration has been read and initialized.
    :raises: Exception if errors found in configuration
    :return:
    """
    logger.info(" ")
    logger.info("==========  VERIFYING CONFIGURATION CONSISTENCY  ===========")

    logger.info(" ")
    logger.info("==========  VERIFYING CONFIGURATION CONSISTENCY  ===========")

    logger.info("\n------------------- BEGIN CONFIG DUMP ------------------------\n ")
    logger.info("CONFIG.GENERAL.database_is_rac : " + str(CONFIG.GENERAL.database_is_rac))
    logger.info("CONFIG.GENERAL.dataguard_use_private_ip : " + str(CONFIG.GENERAL.dataguard_use_private_ip))
    logger.info("CONFIG.GENERAL.ora_user_name : " + (CONFIG.GENERAL.ora_user_name))
    logger.info("CONFIG.GENERAL.ssh_user_name : " + (CONFIG.GENERAL.ssh_user_name))
    logger.info("CONFIG.GENERAL.uri_to_check : " + (CONFIG.GENERAL.uri_to_check))
    logger.info("CONFIG.GENERAL.dr_method : " + (CONFIG.GENERAL.dr_method))
    logger.info("CONFIG.DB_PRIM.db_host_domain : " + (CONFIG.DB_PRIM.db_host_domain))
    logger.info("CONFIG.DB_PRIM.db_hostname : " + (CONFIG.DB_PRIM.db_hostname))
    logger.info("CONFIG.DB_PRIM.db_name : " + (CONFIG.DB_PRIM.db_name))
    logger.info("CONFIG.DB_PRIM.db_port : " + (CONFIG.DB_PRIM.db_port))
    logger.info("CONFIG.DB_PRIM.db_unique_name : " + (CONFIG.DB_PRIM.db_unique_name))
    logger.info("CONFIG.DB_PRIM.host_fqdn : " + (CONFIG.DB_PRIM.host_fqdn))
    logger.info("CONFIG.DB_PRIM.host_ip : " + (CONFIG.DB_PRIM.host_ip))
    logger.info("CONFIG.DB_PRIM.local_ip : " + (CONFIG.DB_PRIM.local_ip))
    logger.info("CONFIG.DB_PRIM.os_version : " + (CONFIG.DB_PRIM.os_version))
    logger.info("CONFIG.DB_PRIM.pdb_name : " + (CONFIG.DB_PRIM.pdb_name))
    # logger.info("CONFIG.DB_PRIM.rac_scan_ip : " + str(CONFIG.DB_PRIM.rac_scan_ip))
    logger.info("CONFIG.DB_PRIM.sysdba_user_name: " + (CONFIG.DB_PRIM.sysdba_user_name))
    logger.info("CONFIG.DB_STBY.db_host_domain: " + (CONFIG.DB_STBY.db_host_domain))
    logger.info("CONFIG.DB_STBY.db_hostname : " + (CONFIG.DB_STBY.db_hostname))
    logger.info("CONFIG.DB_STBY.db_name : " + (CONFIG.DB_STBY.db_name))
    logger.info("CONFIG.DB_STBY.db_port : " + (CONFIG.DB_STBY.db_port))
    logger.info("CONFIG.DB_STBY.db_unique_name : " + (CONFIG.DB_STBY.db_unique_name))
    logger.info("CONFIG.DB_STBY.host_fqdn : " + (CONFIG.DB_STBY.host_fqdn))
    logger.info("CONFIG.DB_STBY.host_ip : " + (CONFIG.DB_STBY.host_ip))
    logger.info("CONFIG.DB_STBY.local_ip : " + (CONFIG.DB_STBY.local_ip))
    logger.info("CONFIG.DB_STBY.os_version : " + (CONFIG.DB_STBY.os_version))
    logger.info("CONFIG.DB_STBY.pdb_name :  " + (CONFIG.DB_STBY.pdb_name))
    logger.info("CONFIG.DB_STBY.sysdba_user_name : " + (CONFIG.DB_STBY.sysdba_user_name))
    logger.info("CONFIG.WLS_PRIM.cluster_node_fqdns : " + str(CONFIG.WLS_PRIM.cluster_node_fqdns))
    logger.info("CONFIG.WLS_PRIM.cluster_node_local_ips : " + str(CONFIG.WLS_PRIM.cluster_node_local_ips))
    logger.info("CONFIG.WLS_PRIM.cluster_node_os_versions : " + str(CONFIG.WLS_PRIM.cluster_node_os_versions))
    logger.info("CONFIG.WLS_PRIM.cluster_node_public_ips : " + str(CONFIG.WLS_PRIM.cluster_node_public_ips))
    logger.info("CONFIG.WLS_PRIM.cluster_size : " + str(CONFIG.WLS_PRIM.cluster_size))
    logger.info("CONFIG.WLS_PRIM.domain_home :" + (CONFIG.WLS_PRIM.domain_home))
    logger.info("CONFIG.WLS_PRIM.domain_name : " + (CONFIG.WLS_PRIM.domain_name))
    logger.info("CONFIG.WLS_PRIM.front_end_ip : " + (CONFIG.WLS_PRIM.front_end_ip))
    logger.info("CONFIG.WLS_PRIM.managed_server_hosts : " + str(CONFIG.WLS_PRIM.managed_server_hosts))
    logger.info("CONFIG.WLS_PRIM.managed_server_names : " + str(CONFIG.WLS_PRIM.managed_server_names))
    logger.info("CONFIG.WLS_PRIM.mw_home : " + (CONFIG.WLS_PRIM.mw_home))
    logger.info("CONFIG.WLS_PRIM.node_manager_host_ips : " + str(CONFIG.WLS_PRIM.node_manager_host_ips))
    logger.info("CONFIG.WLS_PRIM.wl_home : " + (CONFIG.WLS_PRIM.wl_home))
    logger.info("CONFIG.WLS_PRIM.wls_home : " + (CONFIG.WLS_PRIM.wls_home))
    logger.info("CONFIG.WLS_PRIM.wlsadm_host_domain : " + (CONFIG.WLS_PRIM.wlsadm_host_domain))
    logger.info("CONFIG.WLS_PRIM.wlsadm_host_ip : " + (CONFIG.WLS_PRIM.wlsadm_host_ip))
    logger.info("CONFIG.WLS_PRIM.wlsadm_hostname : " + (CONFIG.WLS_PRIM.wlsadm_hostname))
    logger.info("CONFIG.WLS_PRIM.wlsadm_listen_port : " + (CONFIG.WLS_PRIM.wlsadm_listen_port))
    logger.info("CONFIG.WLS_PRIM.wlsadm_nm_hostname : " + (CONFIG.WLS_PRIM.wlsadm_nm_hostname))
    logger.info("CONFIG.WLS_PRIM.wlsadm_nm_port : " + (CONFIG.WLS_PRIM.wlsadm_nm_port))
    logger.info("CONFIG.WLS_PRIM.wlsadm_nm_type :" + (CONFIG.WLS_PRIM.wlsadm_nm_type))
    logger.info("CONFIG.WLS_PRIM.wlsadm_server_name : " + (CONFIG.WLS_PRIM.wlsadm_server_name))
    logger.info("CONFIG.WLS_STBY.wlsadm_user_name : " + (CONFIG.WLS_STBY.wlsadm_user_name))
    logger.info("CONFIG.WLS_STBY.cluster_node_fqdns :" + str(CONFIG.WLS_STBY.cluster_node_fqdns))
    logger.info("CONFIG.WLS_STBY.cluster_node_local_ips :" + str(CONFIG.WLS_STBY.cluster_node_local_ips))
    logger.info("CONFIG.WLS_STBY.cluster_node_os_versions : " + str(CONFIG.WLS_STBY.cluster_node_os_versions))
    logger.info("CONFIG.WLS_STBY.cluster_node_public_ips :" + str(CONFIG.WLS_STBY.cluster_node_public_ips))
    logger.info("CONFIG.WLS_STBY.cluster_size :" + str(CONFIG.WLS_STBY.cluster_size))
    logger.info("CONFIG.WLS_STBY.domain_home : " + (CONFIG.WLS_STBY.domain_home))
    logger.info("CONFIG.WLS_STBY.domain_name : " + (CONFIG.WLS_STBY.domain_name))
    logger.info("CONFIG.WLS_STBY.front_end_ip : " + (CONFIG.WLS_STBY.front_end_ip))
    logger.info("CONFIG.WLS_STBY.managed_server_hosts : " + str(CONFIG.WLS_STBY.managed_server_hosts))
    logger.info("CONFIG.WLS_STBY.managed_server_names : " + str(CONFIG.WLS_STBY.managed_server_names))
    logger.info("CONFIG.WLS_STBY.mw_home : " + (CONFIG.WLS_STBY.mw_home))
    logger.info("CONFIG.WLS_STBY.node_manager_host_ips : " + str(CONFIG.WLS_STBY.node_manager_host_ips))
    logger.info("CONFIG.WLS_STBY.wl_home : " + (CONFIG.WLS_STBY.wl_home))
    logger.info("CONFIG.WLS_STBY.wls_home : " + (CONFIG.WLS_STBY.wls_home))
    logger.info("CONFIG.WLS_STBY.wlsadm_host_domain : " + (CONFIG.WLS_STBY.wlsadm_host_domain))
    logger.info("CONFIG.WLS_STBY.wlsadm_host_ip : " + (CONFIG.WLS_STBY.wlsadm_host_ip))
    logger.info("CONFIG.WLS_STBY.wlsadm_hostname : " + (CONFIG.WLS_STBY.wlsadm_hostname))
    logger.info("CONFIG.WLS_STBY.wlsadm_listen_port : " + (CONFIG.WLS_STBY.wlsadm_listen_port))
    logger.info("CONFIG.WLS_STBY.wlsadm_nm_hostname : " + (CONFIG.WLS_STBY.wlsadm_nm_hostname))
    logger.info("CONFIG.WLS_STBY.wlsadm_nm_port : " + (CONFIG.WLS_STBY.wlsadm_nm_port))
    logger.info("CONFIG.WLS_STBY.wlsadm_nm_type : " + (CONFIG.WLS_STBY.wlsadm_nm_type))
    logger.info("CONFIG.WLS_STBY.wlsadm_server_name : " + (CONFIG.WLS_STBY.wlsadm_server_name))
    logger.info("CONFIG.WLS_STBY.wlsadm_user_name : " + (CONFIG.WLS_STBY.wlsadm_user_name))
    logger.info("\n------------------- END CONFIG DUMP ------------------------\n\n")

    DRSUtil.test_config_object_fully_initialized(CONFIG.GENERAL)
    DRSUtil.test_config_object_fully_initialized(CONFIG.DB_PRIM)
    DRSUtil.test_config_object_fully_initialized(CONFIG.DB_STBY)
    DRSUtil.test_config_object_fully_initialized(CONFIG.WLS_PRIM)
    DRSUtil.test_config_object_fully_initialized(CONFIG.WLS_STBY)

    A = CONFIG.WLS_PRIM
    B = CONFIG.WLS_STBY
    error_stack = list()
    raise_exception = False

    if A.domain_name != B.domain_name:
        raise_exception = True
        error_stack.append("ERROR: Primary WLS domain name [{}] not equal to Standby WLS domain name [{}]".
                           format(A.domain_name, B.domain_name))

    if A.cluster_size != B.cluster_size:
        raise_exception = True
        error_stack.append("ERROR: Primary WLS cluster size [{}] not equal to Standby WLS cluster size [{}]".
                           format(A.cluster_size, B.cluster_size))

    # Verify that all these lists have the same length
    lst1 = [
        len(A.managed_server_names),
        len(B.managed_server_names),
        len(A.managed_server_hosts),
        len(B.managed_server_hosts)
    ]

    if lst1[1:] != lst1[:-1]:
        raise_exception = True
        error_stack.append("ERROR: WLS Managed Server lists lengths do not match [{}]".format(lst1))

    # Verify that all these lists have the same length
    lst2 = [
        len(A.node_manager_host_ips),
        len(B.node_manager_host_ips),
        len(A.cluster_node_fqdns),
        len(B.cluster_node_fqdns),
        len(A.cluster_node_local_ips),
        len(B.cluster_node_local_ips),
        len(A.cluster_node_public_ips),
        len(B.cluster_node_public_ips),
        len(A.cluster_node_os_versions),
        len(B.cluster_node_os_versions),
    ]

    if lst2[1:] != lst2[:-1]:
        raise_exception = True
        error_stack.append("ERROR: WLS Cluster lists lengths do not match [{}]".format(lst2))

    # Raise an exception if anything above failed
    if raise_exception:
        raise Exception("One or more configuration checks failed. {}".format(error_stack))
    else:
        logger.info("Internal configuration is consistent.  All checks passed!")


def get_is_db_rac(site_role):
    """
    Check if the DB is RAC (cluster)
    :param site_role: the site for which to check the DB RAC status
    :raises: Exception if errors found
    :return: True if RAC DB, else False
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        DB_CONFIG = CONFIG.DB_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        DB_CONFIG = CONFIG.DB_STBY
    else:
        raise Exception("Unknown role {}".format(site_role))

    db_obj = DRSDatabase()
    db_obj.connect_host(DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to {} DB host at IP [{}]".format(site_role, DB_CONFIG.host_ip))
    else:
        raise Exception("Failed to connect to {} DB host [{}] using username [{}] and key file [{}]"
                        .format(site_role, DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name,
                                CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  GET DB RAC PROPERTY SETTING -- {} DATABASE  ==========".format(site_role))
    is_rac = db_obj.get_is_db_rac(CONFIG.GENERAL.ora_user_name)

    logger.info("{} Database RAC configured is [{}]".format(site_role, is_rac))

    if is_rac == 'TRUE':
        return True
    else:
        return False


def get_db_name(site_role):
    """
    Get the DB name for the specified site
    :param site_role: the site for which to get the DB unique name
    :raises: Exception if errors found
    :return: db_name (string)
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        DB_CONFIG = CONFIG.DB_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        DB_CONFIG = CONFIG.DB_STBY
    else:
        raise Exception("Unknown role {}".format(site_role))

    db_obj = DRSDatabase()
    db_obj.connect_host(DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to {} DB host at IP [{}]".format(site_role, DB_CONFIG.host_ip))
    else:
        raise Exception("Failed to connect to {} DB host [{}] using username [{}] and key file [{}]"
                        .format(site_role, DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name,
                                CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  GET DB UNIQUE NAME -- {} DATABASE  ==========".format(site_role))
    db_name = db_obj.get_db_name(CONFIG.GENERAL.ora_user_name)

    logger.info("{} Database name is [{}]".format(site_role, db_name))

    return db_name


def get_db_unique_name(site_role):
    """
    Get the DB unique name for the specified site
    :param site_role: the site for which to get the DB unique name
    :raises: Exception if errors found
    :return: db_unique_name (string)
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        DB_CONFIG = CONFIG.DB_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        DB_CONFIG = CONFIG.DB_STBY
    else:
        raise Exception("Unknown role {}".format(site_role))

    db_obj = DRSDatabase()
    db_obj.connect_host(DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to {} DB host at IP [{}]".format(site_role, DB_CONFIG.host_ip))
    else:
        raise Exception("Failed to connect to {} DB host [{}] using username [{}] and key file [{}]"
                        .format(site_role, DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name,
                                CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  GET DB UNIQUE NAME -- {} DATABASE  ==========".format(site_role))
    db_unique_name = db_obj.get_db_unique_name(CONFIG.GENERAL.ora_user_name)

    logger.info("{} Database unique name is [{}]".format(site_role, db_unique_name))

    return db_unique_name


def check_database_health(site_role, current_db_role, db_unique_name, attempts=1):
    """
    Run prechecks on primary DB to verify that it's UP and Data Guard is correctly configured
    :param site_role:  the site role where to check the DB
    :param current_db_role:  the expected current role of the database
    :param db_unique_name:  the DB unique name
    :param attempts:  the number of time to try and check for expected role (default=once)
    :raises: Exception if errors found in precheck
    :return: None
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        DB_CONFIG = CONFIG.DB_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        DB_CONFIG = CONFIG.DB_STBY
    else:
        raise Exception("Unknown role {}".format(site_role))

    db_obj = DRSDatabase()
    db_obj.connect_host(DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to {} DB host at IP [{}]".format(site_role, DB_CONFIG.host_ip))
    else:
        raise Exception("Failed to connect to {} DB host [{}] using username [{}] and key file [{}]"
                        .format(site_role, DB_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name,
                                CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  VERIFY DATA GUARD CONFIGURATION -- {} DATABASE  ==========".format(site_role))
    result = db_obj.verify_data_guard_config(DB_CONFIG, db_unique_name, CONFIG.GENERAL.ora_user_name, current_db_role,
                                             attempts)

    logger.info("Data Guard configuration verification result is [{}]".format(result))

    db_obj.disconnect_host()


def convert_standby_db_to_physical_standby():
    """
    Convert standby database to a physical standby DB
    :raises: Exception if errors found in precheck
    :return: None
    """

    db_obj = DRSDatabase()
    db_obj.connect_host(CONFIG.DB_STBY.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to STANDBY DB host at IP [{}]".format(CONFIG.DB_STBY.host_ip))
    else:
        raise Exception("Failed to connect to STANDBY DB host [{}] using username [{}] and key file [{}]".
                        format(CONFIG.DB_STBY.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  CONVERT TO PHYSICAL STANDBY -- STANDBY DATABASE [{}]  ==========".
                format(CONFIG.DB_STBY.db_unique_name))
    result = db_obj.convert_to_physical_standby(CONFIG.DB_PRIM, CONFIG.DB_STBY, CONFIG.GENERAL.ora_user_name)

    logger.info("Data Guard conversion result is [{}]".format(result))

    db_obj.disconnect_host()

def convert_standby_db_to_snapshot_standby():
    """
    Convert standby database to snapshot standby DB
    :raises: Exception if errors found in precheck
    :return: None
    """

    db_obj = DRSDatabase()
    #we try by connecting to primary db host instead to stby db host
    #db_obj.connect_host(CONFIG.DB_STBY.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    db_obj.connect_host(CONFIG.DB_PRIM.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to PRIMARY DB host at IP [{}]".format(CONFIG.DB_STBY.host_ip))
    else:
        raise Exception("Failed to connect to PRIMARY DB host [{}] using username [{}] and key file [{}]".
                        format(CONFIG.DB_PRIM.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  CONVERT TO SNAPSHOT STANDBY -- STANDBY DATABASE [{}]  ==========".
                format(CONFIG.DB_STBY.db_unique_name))
    result = db_obj.convert_to_snapshot_standby(CONFIG.DB_PRIM, CONFIG.DB_STBY, CONFIG.GENERAL.ora_user_name)

    logger.info("Data Guard conversion result is [{}]".format(result))

    db_obj.disconnect_host()


def check_wls_admin_server(WLS_CONFIG, expected_state):
    """
    Run prechecks on primary WLS admin host to verify that Admin Server is in expected state
    :param WLS_CONFIG: The WLS site config to use
    :param expected_state: The WLS Admin Server expected state
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Check Admin Server on host [{}] is in state [{}]".format(WLS_CONFIG.wlsadm_host_ip, expected_state))
    current_state = wls_obj.get_wls_admin_server_status(WLS_CONFIG)

    if current_state not in expected_state:
        logger.fatal("ERROR: WLS Admin Server state mismatch")
        raise Exception("ERROR: WLS Admin Server state mismatch. Expected state [{}]. Actual state [{}]".
                        format(expected_state, current_state))

    wls_obj.disconnect_host()


def check_wls_managed_server(WLS_CONFIG, server_name, server_host, expected_state):
    """
    Run prechecks on primary WLS admin host to verify that Manager Server is in expected state
    :param WLS_CONFIG: The WLS site config to use
    :param server_name: Name of managed server
    :param server_host: Host on which managed server is running
    :param expected_state: expected state for managed server
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info(" ")
    logger.info(
        "Check Managed Server [{}] on host [{}] is in state [{}]".format(server_name, server_host, expected_state))
    current_state = wls_obj.get_wls_managed_server_status(WLS_CONFIG, server_name, server_host)

    if current_state not in expected_state:
        logger.fatal("ERROR: WLS Managed Server [{}::{}] state mismatch".format(server_name, server_host))
        raise Exception("ERROR: WLS Managed Server [{}::{}] state mismatch. Expected state [{}]. Actual state [{}]".
                        format(server_name, server_host, expected_state, current_state))

    wls_obj.disconnect_host()


def check_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name, expected_state):
    """
    Check that node manager on nm_host_ip is in expected state
    :param WLS_CONFIG: The WLS site config to use
    :param nm_host_ip: Host IP on which node manager is running
    :param nm_host_name: Hostname on which node manager is running
    :param expected_state: expected state for node manager
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(nm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info(
        "Check Node Manager host [{}::{}] is in state [{}]".format(nm_host_name, nm_host_ip, expected_state))
    current_state = wls_obj.get_wls_node_manager_status(WLS_CONFIG, nm_host_name)

    if current_state != expected_state:
        err_msg = "ERROR: Node Manager on host [{}::{}] has state mismatch. Expected state [{}]. Actual state [{}]" \
            .format(nm_host_name, nm_host_ip, expected_state, current_state)
        logger.fatal(err_msg)
        raise Exception(err_msg)

    wls_obj.disconnect_host()

#v13
def check_primary_frontend_in_stby(primary_cluster_frontend):
    # check if frontend name is resolvable in stby hosts
    # connect to stby wls hosts
    # run the script check_frontend.sh passing the primary frontend hostname as a parameter
    if primary_cluster_frontend == "no-frontend":
        logger.warning("WARNING: Primary cluster frontend hostname is NOT configured!")
        logger.warning("WARNING: Continuing with DR setup, but it should be configured with a virtual frontend name")
    else:
        script_params = [
            primary_cluster_frontend
        ]
        stby_wls = DRSWls()
        for host_ip in CONFIG.WLS_STBY.cluster_node_public_ips:
            stby_wls.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
            try:
                stby_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                 CONSTANT.DRS_SCRIPT_FMW_CHECK_FRONTEND_NAME, script_params,
                                                 None,
                                                 CONFIG.GENERAL.ora_user_name, oraenv=True)
            except Exception as e:
                stby_wls.disconnect_host()
                logger.fatal(
                    "ERROR: Primary cluster frontend name [{}] is not resolved from the standby host [{}].".format(
                        primary_cluster_frontend, host_ip))
                logger.fatal(
                    "Verify that the primary cluster frontend name is correctly set, and check that it is resolvable "
                    "from the standby hosts as explained in the DR whitepaper.")
                sys.exit(1)
            stby_wls.disconnect_host()


def check_wls_stack(site_role, expected_state):
    """
    Check that the WLS stack is in expected state
    :param site_role: The site for which to perform the action (PRIMARY OR STANDBY)
    :param expected_state: expected state for node manager
    :raises: Exception if errors found in precheck
    :return: None
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        WLS_CONFIG = CONFIG.WLS_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        WLS_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown site role [{}]".format(site_role))

    if expected_state == "RUNNING":
        server_state = "RUNNING"
        nm_state = "NM_RUNNING"
    elif expected_state == "SHUTDOWN":
        server_state = "SHUTDOWN"
        nm_state = "NM_NOT_RUNNING"
    else:
        raise Exception("Unknown expected state [{}]".format(expected_state))

    logger.info("===========  CHECK WLS STACK EXPECTED STATE [{}] FOR [{}] SITE ==========".
                format(expected_state, site_role))

    logger.info(" ")
    logger.info("===========  CHECKING ALL MANAGED SERVER STATES [{}] ==========".format(site_role))
    logger.info(" ")
    for i in range(len(WLS_CONFIG.managed_server_names)):
        server_name = WLS_CONFIG.managed_server_names[i]
        server_host = WLS_CONFIG.managed_server_hosts[i]
        check_wls_managed_server(WLS_CONFIG, server_name, server_host, server_state)

    logger.info(" ")
    logger.info("===========  CHECKING ADMIN SERVER STATE [{}] ==========".format(site_role))
    logger.info(" ")
    check_wls_admin_server(WLS_CONFIG, server_state)

    logger.info(" ")
    logger.info("===========  CHECKING ALL NODE MANAGER STATES [{}] ==========".format(site_role))
    logger.info(" ")
    for i in range(len(WLS_CONFIG.node_manager_host_ips)):
        nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
        nm_host_name = WLS_CONFIG.managed_server_hosts[i]
        check_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name, nm_state)


def stop_wls_admin_server(WLS_CONFIG):
    """
    Stop the WLS admin server
    :param WLS_CONFIG: The WLS site config to use
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Stop Admin Server on host [{}]".format(WLS_CONFIG.wlsadm_host_ip))
    wls_obj.stop_wls_admin_server(WLS_CONFIG)

    wls_obj.disconnect_host()


def stop_wls_managed_server(WLS_CONFIG, server_name, server_host):
    """
    Stop the managed server
    :param WLS_CONFIG: The WLS site config to use
    :param server_name: Name of managed server
    :param server_host: Host on which managed server is running
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Stop Managed Server [{}] on host [{}]".format(server_name, server_host))
    wls_obj.stop_wls_managed_server(WLS_CONFIG, server_name, server_host)

    wls_obj.disconnect_host()


def stop_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name):
    """
    Stop the node manager
    :param WLS_CONFIG: The WLS site config to use
    :param nm_host_ip: Host IP on which node manager is running
    :param nm_host_name: Hostname on which node manager is running
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(nm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Stop Node Manager host [{}::{}]".format(nm_host_name, nm_host_ip))
    wls_obj.stop_wls_node_manager(WLS_CONFIG, nm_host_name)

    wls_obj.disconnect_host()


def start_wls_admin_server(WLS_CONFIG):
    """
    Start the primary WLS admin server
    :param WLS_CONFIG: The WLS site config to use
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Start Admin Server on host [{}]".format(WLS_CONFIG.wlsadm_host_ip))
    wls_obj.start_wls_admin_server(WLS_CONFIG)

    wls_obj.disconnect_host()


def start_wls_managed_server(WLS_CONFIG, server_name, server_host):
    """
    Start the managed server
    :param WLS_CONFIG: The WLS site config to use
    :param server_name: Name of managed server
    :param server_host: Host on which managed server is running
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Start Managed Server [{}] on host [{}]".format(server_name, server_host))
    wls_obj.start_wls_managed_server(WLS_CONFIG, server_name, server_host)

    wls_obj.disconnect_host()


def start_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name):
    """
    Start the node manager
    :param WLS_CONFIG: The WLS site config to use
    :param nm_host_ip: Host IP on which node manager is running
    :param nm_host_name: Hostname on which node manager is running
    :raises: Exception if errors found in precheck
    :return: None
    """
    wls_obj = DRSWls()
    wls_obj.connect_host(nm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    logger.info("Start Node Manager host [{}::{}]".format(nm_host_name, nm_host_ip))
    wls_obj.start_wls_node_manager(WLS_CONFIG, nm_host_name)

    wls_obj.disconnect_host()


def stop_wls_stack(site_role, stop_nm=True, verify_check=True):
    """
    Stop the primary site WLS stack by stopping components in this order:
        - Stop all managed servers
        - Stop admin server
        - Stop node managers
    :param site_role: The site for which to perform the action (PRIMARY OR STANDBY)
    :param stop_nm: Specifies whether we should stop Node Managers as well.  Default=True (YES).
    :param verify_check: Check and verify at each stage that all stack components are in expected state. Note that this
    check can consume significantly more time and should only be performed if essential (e.g. during debugging)
    :return: None
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        WLS_CONFIG = CONFIG.WLS_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        WLS_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown site role [{}]".format(site_role))

    logger.info("===========  BEGIN WLS STACK STOP -- [{}] SITE ==========".format(site_role))

    # =============================================================================================================
    # start all the node managers (just in case they are not running)
    logger.info(" ")
    logger.info("===========  START ALL NODE MANAGERS [{}] ==========".format(site_role))
    logger.info(" ")
    for i in range(len(WLS_CONFIG.node_manager_host_ips)):
        nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
        nm_host_name = WLS_CONFIG.managed_server_hosts[i]
        logger.info(" ")
        start_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name)

    if verify_check is True:
        logger.info(" ")
        logger.info("===========  CHECKING ALL NODE MANAGER STATES [{}] ==========".format(site_role))
        logger.info(" ")
        for i in range(len(WLS_CONFIG.node_manager_host_ips)):
            nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
            nm_host_name = WLS_CONFIG.managed_server_hosts[i]
            check_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name, "NM_RUNNING")

    # =============================================================================================================
    # stop all the managed servers
    logger.info(" ")
    logger.info("===========  STOP ALL WLS MANAGED SERVERS [{}] ==========".format(site_role))
    logger.info(" ")
    for i in range(len(WLS_CONFIG.managed_server_names)):
        server_name = WLS_CONFIG.managed_server_names[i]
        server_host = WLS_CONFIG.managed_server_hosts[i]
        logger.info(" ")
        stop_wls_managed_server(WLS_CONFIG, server_name, server_host)

    if verify_check is True:
        logger.info(" ")
        logger.info("===========  CHECKING ALL MANAGED SERVER STATES [{}] ==========".format(site_role))
        logger.info(" ")
        for i in range(len(WLS_CONFIG.managed_server_names)):
            server_name = WLS_CONFIG.managed_server_names[i]
            server_host = WLS_CONFIG.managed_server_hosts[i]
            check_wls_managed_server(WLS_CONFIG, server_name, server_host, "SHUTDOWN FAILED_NOT_RESTARTABLE UNKNOWN")

    # =============================================================================================================
    # stop the admin server
    logger.info(" ")
    logger.info("===========  STOP WLS ADMIN SERVER  [{}] ==========".format(site_role))
    logger.info(" ")
    stop_wls_admin_server(WLS_CONFIG)

    if verify_check is True:
        logger.info(" ")
        logger.info("===========  CHECKING ADMIN SERVER STATE [{}] ==========".format(site_role))
        logger.info(" ")
        check_wls_admin_server(WLS_CONFIG, "SHUTDOWN UNKNOWN")

    # =============================================================================================================
    if stop_nm is True:
        # stop all the node managers
        logger.info(" ")
        logger.info("===========  STOP ALL NODE MANAGERS [{}] ==========".format(site_role))
        logger.info(" ")
        for i in range(len(WLS_CONFIG.node_manager_host_ips)):
            nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
            nm_host_name = WLS_CONFIG.managed_server_hosts[i]
            stop_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name)

        if verify_check is True:
            logger.info(" ")
            logger.info("===========  CHECKING ALL NODE MANAGER STATES [{}] ==========".format(site_role))
            logger.info(" ")
            for i in range(len(WLS_CONFIG.node_manager_host_ips)):
                nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
                nm_host_name = WLS_CONFIG.managed_server_hosts[i]
                check_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name, "NM_NOT_RUNNING")
    # =============================================================================================================

    logger.info("===========  WLS STACK STOP COMPLETED -- [{}] SITE  ==========".format(site_role))


def start_wls_stack(site_role, verify_check=True):
    """
    Start the WLS stack by starting components in this order:
        - Start node managers
        - Start admin server
        - Start all managed servers
    :param site_role: The site for which to perform the action (PRIMARY OR STANDBY)
    :param verify_check: Check and verify at the end that all stack components are in expected state. Note that this
    check can consume significantly more time and should only be performed if essential (e.g. during debugging)
    :return: None
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        WLS_CONFIG = CONFIG.WLS_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        WLS_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown site role [{}]".format(site_role))

    logger.info("===========  BEGIN WLS STACK START -- [{}] SITE ==========".format(site_role))

    # =============================================================================================================
    # start all the node managers
    logger.info(" ")
    logger.info("===========  START ALL NODE MANAGERS [{}] ==========".format(site_role))
    logger.info(" ")
    for i in range(len(WLS_CONFIG.node_manager_host_ips)):
        nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
        nm_host_name = WLS_CONFIG.managed_server_hosts[i]
        logger.info(" ")
        start_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name)

    if verify_check is True:
        logger.info(" ")
        logger.info("===========  CHECKING ALL NODE MANAGER STATES [{}] ==========".format(site_role))
        logger.info(" ")
        for i in range(len(WLS_CONFIG.node_manager_host_ips)):
            nm_host_ip = WLS_CONFIG.node_manager_host_ips[i]
            nm_host_name = WLS_CONFIG.managed_server_hosts[i]
            check_wls_node_manager(WLS_CONFIG, nm_host_ip, nm_host_name, "NM_RUNNING")

    # =============================================================================================================
    # start the admin server
    logger.info(" ")
    logger.info("===========  START WLS ADMIN SERVER  [{}] ==========".format(site_role))
    logger.info(" ")
    start_wls_admin_server(WLS_CONFIG)

    if verify_check is True:
        logger.info(" ")
        logger.info("===========  CHECKING ADMIN SERVER STATE [{}] ==========".format(site_role))
        logger.info(" ")
        check_wls_admin_server(WLS_CONFIG, "RUNNING")

    # =============================================================================================================
    # start  all the managed servers
    logger.info(" ")
    logger.info("===========  START ALL WLS MANAGED SERVERS  [{}] ==========".format(site_role))
    logger.info(" ")
    for i in range(len(WLS_CONFIG.managed_server_names)):
        server_name = WLS_CONFIG.managed_server_names[i]
        server_host = WLS_CONFIG.managed_server_hosts[i]
        logger.info(" ")
        start_wls_managed_server(WLS_CONFIG, server_name, server_host)

    if verify_check is True:
        logger.info(" ")
        logger.info("===========  CHECKING ALL MANAGED SERVER STATES [{}] ==========".format(site_role))
        logger.info(" ")
        for i in range(len(WLS_CONFIG.managed_server_names)):
            server_name = WLS_CONFIG.managed_server_names[i]
            server_host = WLS_CONFIG.managed_server_hosts[i]
            check_wls_managed_server(WLS_CONFIG, server_name, server_host, "RUNNING")

    # =============================================================================================================

    logger.info("===========  WLS STACK START COMPLETED -- [{}] SITE  ==========".format(site_role))


def switchover_database(from_site, to_site):
    """
    Perform database switchover in the indicated direction
    :param from_site: The current primary
    :param to_site: The new primary

    :return: None
    """
    if from_site == CONSTANT.DRS_SITE_ROLE_PRIMARY and to_site == CONSTANT.DRS_SITE_ROLE_STANDBY:
        DB_PRIM_CONFIG = CONFIG.DB_PRIM
        DB_STBY_CONFIG = CONFIG.DB_STBY
    elif from_site == CONSTANT.DRS_SITE_ROLE_STANDBY and to_site == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        DB_PRIM_CONFIG = CONFIG.DB_STBY
        DB_STBY_CONFIG = CONFIG.DB_PRIM
    else:
        raise Exception("Unknown switchover from/to DB roles [{}] and [{}]".format(from_site, to_site))

    logger.info(" ")
    logger.info("==========  SWITCHOVER DATABASE -- FROM [{}] TO [{}]  ===========".format(from_site, to_site))

    db_obj = DRSDatabase()
    db_obj.connect_host(DB_STBY_CONFIG.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    if db_obj.is_host_connected():
        logger.info("Successfully connected to STANDBY DB host at IP [{}]".format(DB_STBY_CONFIG.host_ip))
    else:
        raise Exception("Failed to connect to STANDBY DB host [{}] using username [{}] and key file [{}]".
                        format(CONFIG.DB_STBY.host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file))

    logger.info(" ")
    logger.info("==========  SWITCHOVER DATABASE -- FROM [{}] TO [{}]  ==========".
                format(DB_PRIM_CONFIG.db_unique_name, DB_STBY_CONFIG.db_unique_name))
    result = db_obj.switchover_to_standby(DB_PRIM_CONFIG, DB_STBY_CONFIG, CONFIG.GENERAL.ora_user_name)

    logger.info("Data Guard conversion result is [{}]".format(result))

    db_obj.disconnect_host()


def switchover_full_stack(from_site, to_site):
    """
    Switchover full stack (WLS + DB)
    1) Stop WLS stack at 'from_site'
    2) Switchover database from 'from_site' to 'to_site'
    3) Start WLS stack on 'to_site'
    :return: None
    """

    if from_site == CONSTANT.DRS_SITE_ROLE_PRIMARY and to_site == CONSTANT.DRS_SITE_ROLE_STANDBY:
        DB_STBY_CONFIG = CONFIG.DB_STBY
    elif from_site == CONSTANT.DRS_SITE_ROLE_STANDBY and to_site == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        DB_STBY_CONFIG = CONFIG.DB_PRIM
    else:
        raise Exception("Unknown switchover from/to DB roles [{}] and [{}]".format(from_site, to_site))

    logger.info(" ")
    logger.info("==========  SWITCHOVER FROM [{}] TO [{}]  ===========".format(from_site, to_site))

    logger.info(" ")
    logger.info("===========  CHECK DATABASE ROLE -- [{} SITE]  ==========".format(to_site))
    check_database_health(to_site, CONSTANT.DRS_DB_ROLE_PHYSICAL_STANDBY,
                          DB_STBY_CONFIG.db_unique_name, attempts=15)

    logger.info(" ")
    logger.info("===========  STOP PRIMARY WLS STACK -- ALL NODES  ==========")
    stop_wls_stack(from_site, stop_nm=True, verify_check=True)

    logger.info(" ")
    logger.info("===========  SWITCHOVER DATABASE -- PRIMARY TO STANDBY  ==========")
    switchover_database(from_site, to_site)

    logger.info(" ")
    logger.info("===========  START STANDBY WLS STACK -- ALL NODES  ==========")
    start_wls_stack(to_site, verify_check=True)


def check_soa_infra_url(site_role):
    """
    Check that the SOA infrastructure is UP by connecting to the URL
    :param site_role: The site for which to perform the action (PRIMARY OR STANDBY)
    :raises: Exception if errors found in precheck
    :return: None
    """

    if site_role == CONSTANT.DRS_SITE_ROLE_PRIMARY:
        WLS_CONFIG = CONFIG.WLS_PRIM
    elif site_role == CONSTANT.DRS_SITE_ROLE_STANDBY:
        WLS_CONFIG = CONFIG.WLS_STBY
    else:
        raise Exception("Unknown site role [{}]".format(site_role))

    logger.info("===========  CHECK SOA INFRASTRUCTURE URL FOR [{}] SITE ==========".format(site_role))

    script_params = [
        'https://' + WLS_CONFIG.front_end_ip + CONFIG.GENERAL.uri_to_check,
        WLS_CONFIG.wlsadm_user_name + ':' + CONFIG.WLS_PRIM.wlsadm_password,
    ]

    logger.info("Checking if SOA infrastructure URL [{}] is available ...".format(script_params[0]))

    prim_wls = DRSWls()
    prim_wls.connect_host(WLS_CONFIG.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)

    success = False
    sleep_time = 60
    num_retries = 5
    for retries in range(num_retries):
        try:
            prim_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                     CONSTANT.DRS_SCRIPT_SOA_INFRA_CHECK, script_params, None,
                                                     CONFIG.GENERAL.ora_user_name, oraenv=True)
            success = True
            break
        except Exception as e:
            logger.warn(
                "Caught Exception: SOA infrastruture URL not available yet. retries remaining [{}] sleep for [{}] seconds".format(
                    num_retries - retries, sleep_time))
            time.sleep(sleep_time)

    if success is not True:
        raise Exception("ERROR: Check SOA infrastructure URL [{}] failed after multiple attempts. Giving up.".format(
            script_params[0]))

    logger.info("SUCCESS: SOA infrastructure URL [{}] is available".format(script_params[0]))

def fmw_primary_check_connectivity_to_stby_admin():
    """
    For RSYNC method, check if PRIMARY WLS admin  node has connectivity to stby WLS admin node
    :return: None

    """
    logger.info(" ")
    logger.info("==========  CHECK CONNECTIVITY -- PRIMARY WLS Administration node to STANDBY WLS Administration node  ===========")

    # copy the private keyfile to primary soa host and change it to oracle owner and 600
    ssh_key_tmp_file = '/tmp/tmp_priv_ssh_key' + DRSUtil.generate_unique_filename()
    prim_wls_adminhost = DRSHost()
    prim_wls_adminhost.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name,
                                        CONFIG.GENERAL.ssh_key_file)
    prim_wls_adminhost.copy_local_file_to_host(CONFIG.GENERAL.ssh_key_file, ssh_key_tmp_file)
    remote_cmd = CONSTANT.DRS_CMD_SUDO_CHOWN.format(CONFIG.GENERAL.ora_user_name, ssh_key_tmp_file)
    chown_result = prim_wls_adminhost.execute_host_cmd_sudo_root(remote_cmd)
    logger.info("File ownership change (chown) result = {}".format(chown_result.stdout.strip()))
    remote_cmd = CONSTANT.DRS_CMD_SUDO_CHMOD.format('600', ssh_key_tmp_file)
    chmod_result = prim_wls_adminhost.execute_host_cmd_sudo_root(remote_cmd)
    logger.info("File permissions change (chmod) result = {}".format(chmod_result.stdout.strip()))
    prim_wls_adminhost.disconnect_host()

    # provide the appropriate parameters for the check script
    if CONFIG.GENERAL.dataguard_use_private_ip is True:
        # if rac dataguard_use_private_ip is true we can assume there is DRG
        # so will provide the private ip of the secondary admin node to primary script
        remote_admin_ip = CONFIG.WLS_STBY.cluster_node_local_ips[0]
    else:
        # if rac dataguard_use_private_ip is false we can assume there is NO DRG
        # so will provide the public  ip of the secondary admin node to primary script
        remote_admin_ip = CONFIG.WLS_STBY.wlsadm_host_ip

    script_params = [
        remote_admin_ip,
        ssh_key_tmp_file
    ]
    # run the check script
    prim_wls = DRSWls()
    prim_wls.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    prim_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                             CONSTANT.DRS_SCRIPT_FMW_PRIMARY_CHECK_CONNECTIVITY_TO_STANDBY_ADMIN, script_params, None,
                                             CONFIG.GENERAL.ora_user_name, oraenv=True)
    prim_wls.disconnect_host()

    # Remove the copied ssh keyfile
    prim_wls_adminhost = DRSHost()
    prim_wls_adminhost.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name,
                                    CONFIG.GENERAL.ssh_key_file)
    prim_wls_adminhost.delete_remote_file_from_host(ssh_key_tmp_file, CONFIG.GENERAL.ora_user_name)
    prim_wls_adminhost.disconnect_host()



def fmw_primary_check_db_connectivity():
    """
    Check if PRIMARY FMW node has connectivity to PRIMARY database
    :return: None

    """
    logger.info(" ")
    logger.info("==========  CHECK CONNECTIVITY -- PRIMARY WLS to PRIMARY DB  ===========")

    script_params = [
        CONFIG.WLS_PRIM.domain_name,
        CONFIG.DB_PRIM.sysdba_user_name,
        CONFIG.DB_PRIM.sysdba_password
    ]

    prim_wls = DRSWls()
    prim_wls.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    prim_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                             CONSTANT.DRS_SCRIPT_FMW_PRIMARY_CHECK_DB_CONNECTIVITY, script_params, None,
                                             CONFIG.GENERAL.ora_user_name, oraenv=True)


def fmw_standby_check_db_connectivity():
    """
    Check if STANDBY FMW node has connectivity to PRIMARY database
    :return: None

    """
    logger.info(" ")
    logger.info("==========  CHECK CONNECTIVITY -- STANDBY WLS to PRIMARY DB  ===========")

    prim_pdb_service = CONFIG.DB_PRIM.pdb_name + '.' + CONFIG.DB_PRIM.db_host_domain

    if CONFIG.GENERAL.dataguard_use_private_ip is True:
        # Data Guard is configured DRG and Remote VCN Peering use private ip
        # we got when getting the primary db FQDN
        primary_db_ip = CONFIG.DB_PRIM.local_ip
    else:
        # Otherwise use the supplied public IP
        primary_db_ip = CONFIG.DB_PRIM.host_ip

    script_params = [
        primary_db_ip,
        CONFIG.DB_PRIM.db_port,
        prim_pdb_service,
        CONFIG.WLS_STBY.domain_name,
        CONFIG.DB_STBY.sysdba_user_name,
        CONFIG.DB_STBY.sysdba_password
    ]

    stby_wls = DRSWls()
    for host_ip in CONFIG.WLS_STBY.cluster_node_public_ips:
        # Verify connectivity with DB public ip
        stby_wls.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
        stby_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                 CONSTANT.DRS_SCRIPT_FMW_STANDBY_CHECK_DB_CONNECTIVITY, script_params,
                                                 None,
                                                 CONFIG.GENERAL.ora_user_name, oraenv=True)
        stby_wls.disconnect_host()


def fmw_standby_check_db_scan_ip_connectivity():
    """
    Check if STANDBY FMW node has connectivity to PRIMARY database SCAN IP
    :return: None

    """
    logger.info(" ")
    logger.info("==========  CHECK CONNECTIVITY -- STANDBY WLS to PRIMARY DB SCAN IP ===========")

    prim_pdb_service = CONFIG.DB_PRIM.pdb_name + '.' + CONFIG.DB_PRIM.db_host_domain

    script_params = [
        CONFIG.DB_PRIM.rac_scan_ip,
        CONFIG.DB_PRIM.db_port,
        prim_pdb_service,
        CONFIG.WLS_STBY.domain_name,
        CONFIG.DB_STBY.sysdba_user_name,
        CONFIG.DB_STBY.sysdba_password
    ]

    stby_wls = DRSWls()
    for host_ip in CONFIG.WLS_STBY.cluster_node_public_ips:
        # Verify connectivity with DB public ip
        stby_wls.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
        stby_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                 CONSTANT.DRS_SCRIPT_FMW_STANDBY_CHECK_DB_CONNECTIVITY, script_params,
                                                 None,
                                                 CONFIG.GENERAL.ora_user_name, oraenv=True)
        stby_wls.disconnect_host()


def fmw_dr_setup_primary(verify_check=True):
    """
    Set up DR for the Fusion Middleware (FMW) mid-tier nodes at PRIMARY site
    :param verify_check: Check and verify at the end that SOA app is in expected state. Note that this
    check can consume significantly more time and should only be performed if essential (e.g. during debugging)
    :return: None

    """

    logger.info(" ")
    logger.info("==========  SETUP FMW DR -- PRIMARY SITE  ===========")

    # If dr_method is DBFS
    # fmw_dr_setup_primary.sh DB_SYS_PASSWORD DR_METHOD
    # If dr_method is RSYNC
    # fmw_dr_setup_primary.sh DB_SYS_PASSWORD DR_METHOD REMOTE_ADMIN_NODE_IP REMOTE_SSH_PRIV_KEYFILE

    if CONFIG.GENERAL.dr_method == "DBFS":
        script_params = [
            CONFIG.DB_STBY.sysdba_password,
            CONFIG.GENERAL.dr_method
        ]
    elif CONFIG.GENERAL.dr_method == "RSYNC":
        # copy the private keyfile to primary soa host and change it to oracle owner and 600
        ssh_key_tmp_file = '/tmp/tmp_priv_ssh_key' + DRSUtil.generate_unique_filename()
        prim_wls_adminhost = DRSHost()
        prim_wls_adminhost.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
        prim_wls_adminhost.copy_local_file_to_host(CONFIG.GENERAL.ssh_key_file, ssh_key_tmp_file)
        remote_cmd = CONSTANT.DRS_CMD_SUDO_CHOWN.format(CONFIG.GENERAL.ora_user_name, ssh_key_tmp_file)
        chown_result = prim_wls_adminhost.execute_host_cmd_sudo_root(remote_cmd)
        logger.info("File ownership change (chown) result = {}".format(chown_result.stdout.strip()))
        remote_cmd = CONSTANT.DRS_CMD_SUDO_CHMOD.format('600', ssh_key_tmp_file)
        chmod_result = prim_wls_adminhost.execute_host_cmd_sudo_root(remote_cmd)
        logger.info("File permissions change (chmod) result = {}".format(chmod_result.stdout.strip()))
        prim_wls_adminhost.disconnect_host()

        if CONFIG.GENERAL.dataguard_use_private_ip is True:
            # if rac dataguard_use_private_ip is true we can assume there is DRG
            # so will provide the private ip of the secondary admin node to primary script
            remote_admin_ip = CONFIG.WLS_STBY.cluster_node_local_ips[0]
        else:
            # if rac dataguard_use_private_ip is false we can assume there is NO DRG
            # so will provide the public  ip of the secondary admin node to primary script
            remote_admin_ip = CONFIG.WLS_STBY.wlsadm_host_ip

        script_params = [
            CONFIG.DB_STBY.sysdba_password,
            CONFIG.GENERAL.dr_method,
            remote_admin_ip,
            ssh_key_tmp_file
        ]

    # Run the script fmw_dr_setup_primary.sh on primary WLS admin host
    prim_wls = DRSWls()
    prim_wls.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    prim_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                             CONSTANT.DRS_SCRIPT_FMW_DR_SETUP_PRIMARY, script_params, None,
                                             CONFIG.GENERAL.ora_user_name, oraenv=True)

    # If dr_method is RSYNC, remove the copied ssh keyfile from primary WLS Admin host
    if CONFIG.GENERAL.dr_method == "RSYNC":
        prim_wls_adminhost = DRSHost()
        prim_wls_adminhost.connect_host(CONFIG.WLS_PRIM.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name,
                                    CONFIG.GENERAL.ssh_key_file)
        prim_wls_adminhost.delete_remote_file_from_host(ssh_key_tmp_file, CONFIG.GENERAL.ora_user_name)
        prim_wls_adminhost.disconnect_host()



def fmw_dr_setup_standby_node(index, verify_check=True):
    """
    Set up DR for the specified node of the Fusion Middleware (FMW) mid-tier at STANDBY/SECONDARY site
    :param index: The array index of this node in the CONFIG cluster lists
    :param verify_check: Check and verify at the end that FMW stack and SOA app is in expected state. Note that this
    check can consume significantly more time and should only be performed if essential (e.g. during debugging)
    :return: None
    """
    host_ip = CONFIG.WLS_STBY.cluster_node_public_ips[index]
    host_name = CONFIG.WLS_STBY.cluster_node_fqdns[index].split('.', 1)[0]

    logger.info(" ")
    logger.info("==========  SETUP FMW DR -- STANDBY SITE CLUSTER NODE [{}]  ===========".format(index + 1))

    """
    1) verify DB is a snapshot standby
    2) convert DB to physical standby
    3) verify DB is a physical standby
    4) run fmw script on standby mid-tier node
    5) verify DB is a snapshot standby
    6) start WLS components on this node
    7) check SOA is up
    8) stop WLS components on this node
    """
    # =============================================================================================================

    # 1) Verify that DB is in SNAPSHOT STANDBY mode
    logger.info(" ")
    logger.info("===========  VERIFY STANDBY DB IS A SNAPSHOT STANDBY  ==========")
    check_database_health(CONSTANT.DRS_SITE_ROLE_STANDBY, CONSTANT.DRS_DB_ROLE_SNAPSHOT_STANDBY,
                          CONFIG.DB_STBY.db_unique_name, attempts=15)

    # =============================================================================================================
    # # 2) Convert STANDBY DB to PHYSICAL STANDBY
    logger.info(" ")
    logger.info("===========  CONVERT STANDBY DB TO PHYSICAL STANDBY  ==========")
    convert_standby_db_to_physical_standby()

    # # We sleep here a bit to let the DB state settle down
    sleep_interval = 180
    logger.info("Sleeping for [{}] seconds to let DB state change settle down ...".format(sleep_interval))
    time.sleep(180)

    # =============================================================================================================
    # 3) Verify again that DB is in PHYSICAL STANDBY mode
    logger.info(" ")
    logger.info("===========  VERIFY STANDBY DB IS A PHYSICAL STANDBY  ==========")
    check_database_health(CONSTANT.DRS_SITE_ROLE_STANDBY, CONSTANT.DRS_DB_ROLE_PHYSICAL_STANDBY,
                          CONFIG.DB_STBY.db_unique_name, attempts=15)

    # 4) Execute the FMW setup script on the specified standby node
    logger.info(" ")
    logger.info("===========  EXECUTE FMW STANDBY SETUP SCRIPT ON THIS NODE  ==========")

    prim_pdb_service = CONFIG.DB_PRIM.pdb_name + '.' + CONFIG.DB_PRIM.db_host_domain

    if CONFIG.GENERAL.database_is_rac is True:
        # In case of RAC, pass the 'rac_scan_ip' as the DB ip
        primary_db_ip = CONFIG.DB_PRIM.rac_scan_ip
    elif CONFIG.GENERAL.dataguard_use_private_ip is True:
        # Data Guard is configured using DRG and Remote VCN Peering use private ip
        # we got when getting the primary db FQDN
        primary_db_ip = CONFIG.DB_PRIM.local_ip
    else:
        # Otherwise use the supplied public IP
        primary_db_ip = CONFIG.DB_PRIM.host_ip

    script_params = [
        primary_db_ip,
        CONFIG.DB_PRIM.db_port,
        prim_pdb_service,
        CONFIG.DB_STBY.sysdba_password,
        CONFIG.GENERAL.dr_method
    ]


    stby_wls = DRSWls()
    stby_wls.connect_host(host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
    stby_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                             CONSTANT.DRS_SCRIPT_FMW_DR_SETUP_STANDBY, script_params, None,
                                             CONFIG.GENERAL.ora_user_name, oraenv=True, warn=True)

    # =============================================================================================================
    # 5) Verify that DB is in SNAPSHOT STANDBY mode

    # If DR METHOD is RSYNC, the fmw dr setup script does not perform any dg role conversions
    # so we need to convert standby db to snapshot standby here
    # If DR METHOD is DBFS this is not needed, because the fmw dr setup script does it
    if CONFIG.GENERAL.dr_method == "RSYNC":
        logger.info(" ")
        logger.info("===========  CONVERT STANDBY DB TO SNAPSHOT STANDBY  ==========")
        convert_standby_db_to_snapshot_standby()

    logger.info(" ")
    logger.info("===========  VERIFY STANDBY DB IS A SNAPSHOT STANDBY  ==========")
    check_database_health(CONSTANT.DRS_SITE_ROLE_STANDBY, CONSTANT.DRS_DB_ROLE_SNAPSHOT_STANDBY,
                          CONFIG.DB_STBY.db_unique_name, attempts=15)

    # =============================================================================================================
    # 6) START the WLS components on this node ONLY
    # if argument "--do_not_start" was provided, we do not start the processes nor check soa-infra in standby"
    # so only if the argument is not provided (it is false), we start processes, check soa-infra and stop processes
    if parser_args.do_not_start is False:
        logger.info(" ")
        logger.info("===========  START WLS COMPONENTS -- STANDBY SITE CLUSTER NODE [{}]  ===========".format(index + 1))

        # 6a) Start the Node Manager
        start_wls_node_manager(CONFIG.WLS_STBY, host_ip, host_name)

        # 6b) Start the Admin Server (only if this is the first cluster node)
        if index == 0:
            start_wls_admin_server(CONFIG.WLS_STBY)

        # 6c) Start the Managed Server
        start_wls_managed_server(CONFIG.WLS_STBY, CONFIG.WLS_STBY.managed_server_names[index],
                             CONFIG.WLS_STBY.managed_server_hosts[index])

        # =============================================================================================================
        # 7) Check SOA infrastructure is UP
        logger.info(" ")
        logger.info("===========  CHECK SOA INFRASTRUCTURE URL  ===========")
        check_soa_infra_url(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================
        # 8) Stop WLS Managed server on this node
        # NOTE: We can leave the Admin server and NM running
        logger.info(" ")
        logger.info("===========  STOP MANAGED SERVER -- STANDBY SITE CLUSTER NODE [{}]  ===========".format(index + 1))
        stop_wls_managed_server(CONFIG.WLS_STBY, CONFIG.WLS_STBY.managed_server_names[index],
                            CONFIG.WLS_STBY.managed_server_hosts[index])

def post_setup_clean():
    # v14
    if CONFIG.GENERAL.dr_method == "DBFS":
        # Run script to drop the temporary table DBFS_INFO, created to share dbfs info with secondary
        logger.info(" ")
        logger.info("===========  Drop temporary table created to share info with secondary  ===========")

        prim_pdb_service = CONFIG.DB_PRIM.pdb_name + '.' + CONFIG.DB_PRIM.db_host_domain
        if CONFIG.GENERAL.database_is_rac is True:
            # In case of RAC, pass the 'rac_scan_ip' as the DB ip
            primary_db_ip = CONFIG.DB_PRIM.rac_scan_ip
        elif CONFIG.GENERAL.dataguard_use_private_ip is True:
            # Data Guard is configured using DRG and Remote VCN Peering use private ip
            # we got when getting the primary db FQDN
            primary_db_ip = CONFIG.DB_PRIM.local_ip
        else:
            # Otherwise use the supplied public IP
            primary_db_ip = CONFIG.DB_PRIM.host_ip

        script_params = [
            CONFIG.DB_PRIM.sysdba_user_name,
            CONFIG.DB_PRIM.sysdba_password,
            primary_db_ip,
            CONFIG.DB_PRIM.db_port,
            prim_pdb_service
        ]

        stby_wls = DRSWls()
        stby_wls.connect_host(CONFIG.WLS_STBY.wlsadm_host_ip, CONFIG.GENERAL.ssh_user_name, CONFIG.GENERAL.ssh_key_file)
        stby_wls.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                             CONSTANT.DRS_SCRIPT_POST_SETUP_DROP_TMP_INFO, script_params, None,
                                             CONFIG.GENERAL.ora_user_name, oraenv=True, warn=True)

def main():
    """
    main routine which invokes everything in the right order
    :return:
    """
    global logger
    global parser_args

    try:
        # =============================================================================================================

        # Set up logging
        setup_logging()

        log_header(logger, "BEGIN MAA SOA DR SETUP")

        # =============================================================================================================

        parse_arguments()

        if parser_args.config_dr is True and parser_args.config_test_dr is True:
            parser.print_help()
            print('\nERROR: Specify only one of \'-CH\' \'-C\' or \'-T\' options\n')
            sys.exit(1)

        if parser_args.config_dr is True and parser_args.checks_only is True:
            parser.print_help()
            print('\nERROR: Specify only one of \'-CH\' \'-C\' or \'-T\' options\n')
            sys.exit(1)

        if parser_args.config_test_dr is True and parser_args.checks_only is True:
            parser.print_help()
            print('\nERROR: Specify only one of \'-CH\' \'-C\' or \'-T\' options\n')
            sys.exit(1)

        if parser_args.checks_only is False and parser_args.config_dr is False and parser_args.config_test_dr is False:
            parser.print_help()
            print('\nERROR: Specify at least one of \'-CH\' \'-C\' or \'-T\' options\n')
            sys.exit(1)

        if parser_args.checks_only:
            logger.info("--checks_only option was specified")
        if parser_args.config_dr:
            logger.info("--config_dr option was specified")
        if parser_args.config_test_dr:
            logger.info("--config_test_dr option was was specified")
        if parser_args.skip_checks:
            logger.info("--skip_checks option was was specified")
        if parser_args.do_not_start:
           logger.info("--do_not_start option was was specified")

        # =============================================================================================================

        log_header(logger, "CREATE LOCAL TEMP DIR")
        create_local_tempdir()

        # =============================================================================================================

        log_header(logger, "READ USER YAML CONFIGURATION")
        read_user_yaml_configuration()

        # =============================================================================================================

        log_header(logger, "GET PRIMARY DB HOST FQDN and IP ADDRESS")
        get_db_host_fqdn_and_ips(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "GET STANDBY DB HOST FQDN and IP ADDRESS")
        get_db_host_fqdn_and_ips(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "GET PRIMARY DB ATTRIBUTES")
        CONFIG.DB_PRIM.db_name = get_db_name(CONSTANT.DRS_SITE_ROLE_PRIMARY)
        CONFIG.DB_PRIM.db_unique_name = get_db_unique_name(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "GET STANDBY DB ATTRIBUTES")
        CONFIG.DB_STBY.db_name = get_db_name(CONSTANT.DRS_SITE_ROLE_STANDBY)
        CONFIG.DB_STBY.db_unique_name = get_db_unique_name(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "CHECK IF PRIMARY DATABASE IS RAC (CLUSTER)")

        CONFIG.GENERAL.database_is_rac = get_is_db_rac(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        if (CONFIG.GENERAL.database_is_rac is True) and \
                (re.match(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$', CONFIG.DB_PRIM.rac_scan_ip) is None):
            err = "ERROR: DB config mismatch. DB type is RAC but improper or no value specified for 'rac_scan_ip' " \
                  "in YAML config file. Specify a valid scan IP in YAML config file."
            logger.fatal(err)
            raise Exception(err)
        elif (CONFIG.GENERAL.database_is_rac is False) and (CONFIG.DB_PRIM.rac_scan_ip is not ''):
            err = "ERROR: DB config mismatch. DB type is not RAC but value still specified for 'rac_scan_ip'" \
                  "in YAML config file. 'rac_scan_ip' must be left blank for single-instance DBs."
            logger.fatal(err)
            raise Exception(err)
        else:
            logger.info("DB type and value configured for 'rac_scan_ip' match each other")

        # =============================================================================================================

        log_header(logger, "GET PRIMARY WLS HOST FQDNS and IP ADDRESSES")
        get_all_wls_host_fqdn_and_ips(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "GET STANDBY WLS HOST FQDNS and IP ADDRESSES")
        get_all_wls_host_fqdn_and_ips(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "GET PRIMARY WLS DOMAIN INFORMATION")
        get_wls_domain_name_and_home(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "GET STANDBY WLS DOMAIN INFORMATION")
        get_wls_domain_name_and_home(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "GET PRIMARY WLS DOMAIN CONFIGURATION")
        get_wls_domain_configuration(CONSTANT.DRS_SITE_ROLE_PRIMARY, CONFIG.WLS_PRIM.domain_home)

        log_header(logger, "GET STANDBY WLS DOMAIN CONFIGURATION")
        get_wls_domain_configuration(CONSTANT.DRS_SITE_ROLE_STANDBY, CONFIG.WLS_STBY.domain_home)

        # =============================================================================================================

        log_header(logger, "GET PRIMARY WLS HOME")
        get_wls_home(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "GET STANDBY WLS HOME")
        get_wls_home(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "VERIFY INTERNAL CONFIGURATION")
        verify_internal_configuration()

        # =============================================================================================================

        log_header(logger, "CHECK PRIMARY DATABASE HEALTH")
        check_database_health(CONSTANT.DRS_SITE_ROLE_PRIMARY, CONSTANT.DRS_DB_ROLE_PRIMARY,
                              CONFIG.DB_PRIM.db_unique_name, attempts=15)

        log_header(logger, "CHECK STANDBY DATABASE HEALTH")
        check_database_health(CONSTANT.DRS_SITE_ROLE_STANDBY, CONSTANT.DRS_DB_ROLE_SNAPSHOT_STANDBY,
                              CONFIG.DB_STBY.db_unique_name, attempts=15)

        # =============================================================================================================

        log_header(logger, "CHECK FMW PRIMARY TO PRIMARY DB CONNECTIVITY")
        fmw_primary_check_db_connectivity()

        log_header(logger, "CHECK FMW STANDBY TO PRIMARY DB CONNECTIVITY")
        fmw_standby_check_db_connectivity()

        if CONFIG.GENERAL.database_is_rac:
            log_header(logger, "CHECK FMW STANDBY TO PRIMARY DB SCAN IP CONNECTIVITY - ENABLED - RAC DB")
            fmw_standby_check_db_scan_ip_connectivity()
        else:
            log_header(logger, "CHECK FMW STANDBY TO PRIMARY DB SCAN IP CONNECTIVITY - SKIPPING - SINGLE INSTANCE DB")

        # =============================================================================================================
        #v13
        log_header(logger, "CHECK IF PRIMARY CLUSTER FRONTEND NAME IS RESOLVABLE IN STANDBY HOSTS")
        check_primary_frontend_in_stby(CONFIG.WLS_PRIM.cluster_frontend_host)
        # =============================================================================================================


        # =============================================================================================================
        if CONFIG.GENERAL.dr_method == "RSYNC":
            log_header(logger, "CHECK SSH CONNECTIVITY FROM PRIMARY WLS ADMIN NODE TO STANDBY WLS ADMIN NODE")
            fmw_primary_check_connectivity_to_stby_admin()
        # =============================================================================================================

        if parser_args.skip_checks is False:
            log_header(logger, "VERIFY PRIMARY WLS STACK IS RUNNING")
            check_wls_stack(CONSTANT.DRS_SITE_ROLE_PRIMARY, "RUNNING")

            log_header(logger, "VERIFY STANDBY WLS STACK IS RUNNING")
            check_wls_stack(CONSTANT.DRS_SITE_ROLE_STANDBY, "RUNNING")

            # =========================================================================================================

            log_header(logger, "CHECK SOA INFRASTRUCTURE IS UP -- STANDBY SITE")
            check_soa_infra_url(CONSTANT.DRS_SITE_ROLE_STANDBY)

            log_header(logger, "CHECK SOA INFRASTRUCTURE IS UP -- PRIMARY SITE")
            check_soa_infra_url(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        # =============================================================================================================

        if parser_args.checks_only is True:
            log_header(logger, " FINISHED CHECKS SUCCESSFULLY. EXITING BECAUSE --checks_only FLAG WAS PROVIDED")
            exit(0)

        # =============================================================================================================
        log_header(logger, "PATCH /ETC/HOSTS FILES -- PRIMARY SITE WLS HOSTS")
        patch_all_wls_etc_hosts(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "PATCH /ETC/HOSTS FILES -- STANDBY SITE WLS HOSTS")
        patch_all_wls_etc_hosts(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "PATCH /ETC/OCI-HOSTNAME.CONF FILES -- PRIMARY SITE WLS HOSTS")
        patch_all_wls_etc_oci_hostname_conf(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        log_header(logger, "PATCH /ETC/OCI-HOSTNAME.CONF FILES -- STANDBY SITE WLS HOSTS")
        patch_all_wls_etc_oci_hostname_conf(CONSTANT.DRS_SITE_ROLE_STANDBY)

        # =============================================================================================================

        log_header(logger, "RUN FMW PRIMARY DR CONFIG SCRIPT AT PRIMARY SITE")
        fmw_dr_setup_primary(verify_check=(not parser_args.skip_checks))

        # =============================================================================================================

        log_header(logger, "STOP WLS STACK -- STANDBY SITE")
        stop_wls_stack(CONSTANT.DRS_SITE_ROLE_STANDBY, stop_nm=True, verify_check=(not parser_args.skip_checks))

        # =============================================================================================================

        log_header(logger, "RUN FMW STANDBY DR CONFIG SCRIPT ON ALL STANDBY SITE NODES")
        for index in range(len(CONFIG.WLS_STBY.cluster_node_local_ips)):
            host = CONFIG.WLS_STBY.cluster_node_fqdns[index]
            logger.info(" ")
            logger.info(
                "===========  SET UP FMW DR ON STANDBY NODE [{}] - HOST [{}] ==========".format(index + 1, host))
            fmw_dr_setup_standby_node(index, verify_check=(not parser_args.skip_checks))

        # =============================================================================================================
        # v14
        log_header(logger, "POST DR SETUP CLEAN UP")
        post_setup_clean()

        # =============================================================================================================
        # If argument --do_not_start was passed, we do not need to stop WLS stack in standby, because it has not been started
        # So, only if do_not_start is false we need to stop WLS stack in standby
        if parser_args.do_not_start is False:
            log_header(logger, "STOP WLS STACK AT STANDBY SITE -- (POST DR SETUP)")
            stop_wls_stack(CONSTANT.DRS_SITE_ROLE_STANDBY, stop_nm=False, verify_check=(not parser_args.skip_checks))

        # =============================================================================================================

        log_header(logger, "CONVERT STANDBY DB TO PHYSICAL STANDBY -- (POST DR SETUP)")
        convert_standby_db_to_physical_standby()

        # =============================================================================================================

        if parser_args.config_test_dr:
            log_header(logger, "PERFORMING OPTIONAL SWITCHOVER/SWITCHBACK TEST")

            # Check that SOA is up at primary site
            log_header(logger, "CHECK SOA INFRASTRUCTURE URL -- PRIMARY SITE")
            check_soa_infra_url(CONSTANT.DRS_SITE_ROLE_PRIMARY)

            # Switchover -- PRIMARY to STANDBY
            log_header(logger, "SWITCHOVER FULL STACK -- FROM [{}] TO  [{}] ===========".
                       format(CONSTANT.DRS_SITE_ROLE_PRIMARY, CONSTANT.DRS_SITE_ROLE_STANDBY))
            switchover_full_stack(CONSTANT.DRS_SITE_ROLE_PRIMARY, CONSTANT.DRS_SITE_ROLE_STANDBY)

            # Check that SOA is up at standby site
            log_header(logger, "CHECK SOA INFRASTRUCTURE URL -- STANDBY SITE")
            check_soa_infra_url(CONSTANT.DRS_SITE_ROLE_STANDBY)

            # Switchback -- STANDBY to PRIMARY
            log_header(logger, "SWITCHBACK FULL STACK -- FROM [{}] TO  [{}] ===========".
                       format(CONSTANT.DRS_SITE_ROLE_STANDBY, CONSTANT.DRS_SITE_ROLE_PRIMARY))
            switchover_full_stack(CONSTANT.DRS_SITE_ROLE_STANDBY, CONSTANT.DRS_SITE_ROLE_PRIMARY)

            # Check that SOA is up at primary site
            log_header(logger, "CHECK SOA INFRASTRUCTURE URL -- PRIMARY SITE")
            check_soa_infra_url(CONSTANT.DRS_SITE_ROLE_PRIMARY)

        # =============================================================================================================

        log_header(logger, "MAA SOA DR SETUP FINISHED SUCCESSFULLY!")

        # =============================================================================================================

    except Exception as e:
        logger.error(
            str(e).replace(CONFIG.DB_PRIM.sysdba_password, "*********").replace(CONFIG.WLS_PRIM.wlsadm_password,
                                                                                "*********"))
        sys.exit(1)

"""
 Entry point for the whole thing

"""
if __name__ == "__main__":
    CONFIG = DRS_CONFIG()
    main()
