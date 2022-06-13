# -*- coding: utf-8 -*-
"""
    MAA DR Setup (DRS) library

    This file contains classes and libraries used by the DRS framework.
"""

__author__ = "Oracle "
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """

try:
    import os
except ImportError:
    print("ERROR: Could not import python's os module")
    os = None
    exit(-1)

try:
    import time
except ImportError:
    print("ERROR: Could not import python's time module")
    time = None
    exit(-1)

try:
    from datetime import datetime
except ImportError:
    print("ERROR: Could not import python's datetime module")
    datetime = None
    exit(-1)

try:
    from random import choice
    from string import ascii_uppercase
except ImportError:
    print("ERROR: Could not import python's datetime module")
    choice = None
    ascii_uppercase = None
    exit(-1)

try:
    from fabric import Connection
except ImportError:
    print("ERROR: Could not import python's fabric.Connection module")
    Connection = None
    exit(-1)

try:
    from datetime import datetime
except ImportError:
    print("ERROR: Could not import python's datetime module")
    datetime = None
    exit(-1)

try:
    import re
except ImportError:
    print("ERROR: Could not import python's re module")
    re = None
    exit(-1)

try:
    import logging
except ImportError:
    print("ERROR: Could not import python's logging module")
    logging = None
    exit(-1)

try:
    import yaml
except ImportError:
    print("ERROR: Could not import python's yaml module")
    yaml = None
    exit(-1)

try:
    from drs_config import DRS_CONFIG as CONFIG
except ImportError:
    print("ERROR: Could not import DRS drs_config module")
    CONFIG = None
    exit(-1)

try:
    from drs_const import DRS_CONSTANTS as CONSTANT
except ImportError:
    print("ERROR: Could not import DRS_CONSTANTS from drs_const module")
    CONSTANT = None
    exit(-1)


#
#   DRSLogger
#
class DRSLogger(object):
    """
    Logger object which implements logging to file and stdout (if required).

    """

    def __init__(self, log_filename):
        """
        Initializes a DRSBase object

        :param: log_filename: The full path & name of logfile to use for logging

        :return: A DRSBase object with logging initialized
        """
        self.logger = None
        self.setup_logger(log_filename)
        self.id = "[{}::{}]".format(type(self).__name__, id(self))
        self.logger.debug("Created object " + self.id)

    def setup_logger(self, log_filename):
        """
        Sets up logging

        :param log_filename: full path & name of logfile to use

        :return: None
        """
        logging.basicConfig(
            level=CONSTANT.DRS_LOGGING_DEFAULT_LOG_LEVEL,
            format=CONSTANT.DRS_LOGFILE_STATEMENT_FORMAT,
            handlers=[logging.FileHandler(log_filename)])

        self.logger = logging.getLogger()

    def get_logger(self):
        """
        Returns the logging object
        :return: logger (python logger object)
        """
        return self.logger


#
#   DRSConfiguration
#
class DRSConfiguration(object):
    """
    Implements YAML configuration file parsing for DRS

    """

    def __init__(self, drs_config_file):
        """
        Initializes a DRSConfiguration object

        :param drs_config_file: The configuration file to read configuration from

        :return: An initialized DRSConfiguration object for managing user configuration
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.drs_config_file = drs_config_file
        self.config_dict = dict()
        self.id = "[{}::{}]".format(type(self).__name__, id(self))
        self.logger.debug("Created object " + self.id)

        self.load_configuration()

    def load_configuration(self):
        """
        Read master configuration from configuration file
        :return: None
        """
        self.config_dict.clear()
        self.logger.info("Loading configuration from config file: " + self.drs_config_file)
        with open(self.drs_config_file, 'r') as f:
            self.config_dict = yaml.load(f, Loader=yaml.BaseLoader)  # need to use BaseLoader to get strings by default

    def print_configuration_to_logfile(self):
        """
        Prints the loaded configuration
        :return:
        """
        # self.logger.info("Printing configuration to logfile: " + self.logger.handlers[0].baseFilename)
        self.logger.debug("Printing configuration to logfile")

        print_dict = self.__clean_config_dict(self.config_dict)

        if len(print_dict) > 0:
            # print(yaml.dump(print_dict, indent=4, sort_keys=False))
            self.logger.debug("\n\n" + yaml.dump(print_dict, indent=4, sort_keys=False))

    def get_configuration_dict(self):
        """
        Return the configuration as a python dictionary
        :return: config_dict (dict)
        """
        return self.config_dict

    def __clean_config_dict(self, unclean_dict):
        """
        This method erases all clear-text passwords from a dictionary and returns a copy
        Usually used before printing the config in order to sanitize & remove secure info
        :return: unclean_dict: A config dictionary with all passwords erases
        """
        for key, value in unclean_dict.items():
            if isinstance(value, dict):
                self.__clean_config_dict(value)
            else:
                if "password" in key:
                    unclean_dict[key] = '********'

        return unclean_dict


#
#   DRSHost
#
class DRSHost(object):
    """
    Implements host object that internally use Fabric-based connection services.

    """

    def __init__(self):
        """
        Initializes a DRSHost object

        :return: An initialized DRSHost object
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.fab_conn = None
        self.host_ip = None
        self.user_name = None
        self.key_file = None
        self.id = "[{}::{}]".format(type(self).__name__, id(self))
        self.logger.debug("Created object " + self.id)

    def is_connected(self):
        """
        Checks if host connection is active/open
        :return: True if connected, else False
        """
        if self.fab_conn is not None and self.fab_conn.is_connected:
            self.logger.debug("Connection to host [{}] IS open/active".format(self.host_ip))
            return True
        else:
            self.logger.debug("Connection to host [{}] is NOT open/active".format(self.host_ip))
            return False

    def connect_host(self, host_ip, user_name, key_file):
        """
        Open a SSH connection to host

        :param host_ip: The IP address of the host
        :param user_name: The user name to use when connecting
        :param key_file: full path & name of SSH auth key file

        :return: None
        """
        self.host_ip = host_ip
        self.user_name = user_name
        self.key_file = key_file


        if self.is_connected() is not True:
            self.logger.info("Connecting to host [{}] as user [{}]".format(host_ip, user_name))
            # Changed key_file to list to avoid fabric issue #2007
            self.fab_conn = Connection(host=self.host_ip, user=self.user_name, connect_timeout=30,
                                       connect_kwargs={"key_filename": self.key_file.split()})
            self.fab_conn.open()

            self.logger.info("Connected to host [{}] as user [{}]".format(host_ip, user_name))
        else:
            self.logger.warning(
                "WARNING: Already connected to host [{}] as user [{}]".format(self.host_ip, self.user_name))

    def disconnect_host(self):
        """
        Close connection to host

        :return: None
        """
        if self.is_connected() is True:
            self.fab_conn.close()
            self.logger.debug("Successfully disconnected from host [{}]".format(self.host_ip))
        else:
            self.logger.warning("WARNING: Not connected to host [{}] as user [{}]".format(self.host_ip, self.user_name))

        self.host_ip = None
        self.user_name = None
        self.key_file = None

    def execute_host_cmd_sudo_user(self, cmd, user_name, warn=False):
        """
        Executes specified command on connected host
        :param cmd: Command to execute
        :param user_name: The user_name to use when executing 'cmd'

        :return:  The output of the command
        """
        fmt_cmd = CONSTANT.DRS_CMD_EXECUTE_SUDO_SU_CMD_FMT.format(user_name, cmd)
        #self.logger.debug("Executing cmd [{}] as user [{}] with warn [{}] on host [{}]".format(fmt_cmd, user_name, warn, self.host_ip))
        secure_cmd = cmd.replace(CONFIG.DB_PRIM.sysdba_password, "******")
        secure_cmd = secure_cmd.replace(CONFIG.WLS_PRIM.wlsadm_password, "******")
        self.logger.debug(
            "Executing cmd [{}] as user [{}] with warn [{}] on host [{}]".format(secure_cmd, user_name, warn,
                                                                                 self.host_ip))
        # r = self.fab_conn.run(fmt_cmd, pty=True, hide=True)
        # r = self.fab_conn.run(fmt_cmd, pty=False, echo=True)
        r = self.fab_conn.run(fmt_cmd, pty=False, warn=warn)

        self.logger.debug("Sudo user [{}] command output = {}".format(user_name, r.stdout.strip()))
        return r

    def execute_host_cmd_sudo_user_pty(self, cmd, user_name, warn=False):
        # For bug 33748539 (not used)
        """
        Executes specified command on connected host
        :param cmd: Command to execute
        :param user_name: The user_name to use when executing 'cmd'

        :return:  The output of the command
        """
        fmt_cmd = CONSTANT.DRS_CMD_EXECUTE_SUDO_SU_CMD_FMT.format(user_name, cmd)
        # self.logger.debug("Executing cmd [{}] as user [{}] with warn [{}] on host [{}]".format(fmt_cmd, user_name, warn, self.host_ip))
        secure_cmd = cmd.replace(CONFIG.DB_PRIM.sysdba_password, "******")
        secure_cmd = secure_cmd.replace(CONFIG.WLS_PRIM.wlsadm_password, "******")
        self.logger.debug(
            "SECURED Executing cmd [{}] as user [{}] with warn [{}] on host [{}]".format(secure_cmd, user_name, warn,
                                                                                         self.host_ip))
        # r = self.fab_conn.run(fmt_cmd, pty=True, hide=True)
        # r = self.fab_conn.run(fmt_cmd, pty=False, echo=True)
        r = self.fab_conn.run(fmt_cmd, pty=True)

        self.logger.debug("Sudo user [{}] command output = {}".format(user_name, r.stdout.strip()))
        return r

    def execute_host_cmd_sudo_root(self, cmd):
        """
        Executes sudo command on connected host (uses 'sudo cmd')
        :param cmd: Command to execute
        :return:  The output of the command
        """
        fmt_cmd = CONSTANT.DRS_CMD_EXECUTE_SUDO_CMD_ONLY_FMT.format(cmd)
        #self.logger.debug("Executing sudo cmd [{}] on host [{}]".format(fmt_cmd, self.host_ip))
        secure_cmd = cmd.replace(CONFIG.DB_PRIM.sysdba_password, "******")
        secure_cmd = secure_cmd.replace(CONFIG.WLS_PRIM.wlsadm_password, "******")
        self.logger.debug("Executing sudo cmd [{}] on host [{}]".format(secure_cmd, self.host_ip))
        # r = self.fab_conn.run(fmt_cmd, pty=True, hide=True)
        # r = self.fab_conn.run(fmt_cmd, pty=False, echo=True)
        r = self.fab_conn.run(fmt_cmd, pty=False)

        self.logger.debug("Sudo command output = {}".format(r.stdout.strip()))
        return r

    def copy_local_file_to_host(self, local_file, remote_file):
        """
        Copy a local file to a remote file on this host
        :param local_file: full path & name of the local file to copy
        :param remote_file: the remote file name to copy the local file to
                (NOTE: this is the complete path , not just the remote directory name)

        :return:
        """
        self.logger.debug("Copying local file [{}] to remote file [{}:{}]".
                          format(local_file, self.host_ip, remote_file))
        self.fab_conn.put(local_file, remote=remote_file)

    def copy_remote_file_from_host(self, remote_file, local_file):
        """
        Copy a file from a remote directory on this host to a local dir
        :param remote_file: full path & name of the remote file to copy
        :param local_file: full path & name of the local file to copy
                (note: this is NOT just the local dir, but actual dir + filename to use)

        :return: The full path to the local copied file
        """
        self.logger.debug("Copying remote file [{}:{}] to local file [{}]".
                          format(self.host_ip, remote_file, local_file))
        self.fab_conn.get(remote_file, local_file)
        return local_file

    def delete_remote_file_from_host(self, remote_file, user_name):
        """
        Delete a file from a remote directory on this host
        :param remote_file: full path & name of the remote file to copy
        :param user_name: user who owns file to be deleted

        :return: The command result
        """
        self.logger.debug("Deleting remote file [{}:{}] as user[{}]".format(self.host_ip, remote_file, user_name))
        remote_cmd = CONSTANT.DRS_CMD_OPC_RM_FILE.format(remote_file)
        return self.execute_host_cmd_sudo_user(remote_cmd, user_name)

    def backup_remote_file_on_host(self, remote_file):
        """
        Save a backup of a remote file on that host.  Typically used before modifying that file.
        :param remote_file: full path & name of the remote file to backup

        :return: The full path and name of the remote backup file
        """
        save_as = remote_file + '.backup.' + DRSUtil.generate_unique_filename()
        self.logger.debug("Backing up remote file [{}] to [{}] on host [{}]".
                          format(remote_file, save_as, self.host_ip))
        remote_cmd = CONSTANT.DRS_CMD_OPC_BACKUP_FILE.format(remote_file, save_as)
        return self.execute_host_cmd_sudo_root(remote_cmd)

    def execute_internal_script_on_host(self, interpreter, script_name, script_params_list, deps_list, user_name,
                                        oraenv=True, warn=False):
        """
        Executes script on this host object (typically a remote host)
        NOTE: Only works (for now) for executing scripts as user "oracle" on remote host
        :param interpreter: Script interpreter (e.g. '/bin/sh', 'python', '/u01/oracle/common/bin/wlst.sh', etc.)
        :param script_name: the name of the script to execute
        :param script_params_list: an  list of params to pass to the script (Optional.  Can be 'None')
        :param deps_list: a list of dependency scripts used by the primary script (Optional.  Can be 'None')
        :param user_name: The user name to use when executing the script (e.g. sudo su - user_name).
                NOTE: The 'exec_user_name' is only used to execute the script, however we must use a different
                user name ('opc') to stage/delete the script.
        :param oraenv: Whether to source oraenv before executing command ('True' if not specified)

        :return: The output of the script execution
        """
        remote_staging_dir = '/tmp/' + DRSUtil.generate_unique_filename()
        remote_script_path = remote_staging_dir + '/' + script_name

        # Create staging directory on host
        remote_cmd = CONSTANT.DRS_CMD_OPC_MKDIR.format(remote_staging_dir)
        mkdir_result = self.execute_host_cmd_sudo_user(remote_cmd, self.user_name, warn)
        self.logger.debug("Create directory (mkdir) result = {}".format(mkdir_result.stdout.strip()))

        if script_params_list is not None:
            assert(isinstance(script_params_list, (list,)))  # make sure this is a list
            param_string = ' '.join(list(script_params_list))
            remote_script_path += ' '
            remote_script_path += param_string

        # Stage script file on host
        self.copy_local_file_to_host(CONSTANT.DRS_INTERNAL_SCRIPT_DIR + '/' + script_name,
                                     remote_staging_dir + '/' + script_name)

        # Stage dependency files on host
        if deps_list is not None:
            for dep in deps_list:
                self.copy_local_file_to_host(CONSTANT.DRS_INTERNAL_SCRIPT_DIR + '/' + dep,
                                             remote_staging_dir + '/' + dep)

        # Modify remote directory ownership and permissions if necessary
        if user_name != self.user_name:
            self.logger.debug(
                "Changing remote dir [{}] ownership from [{}] to [{}]".format(remote_staging_dir, self.user_name,
                                                                              user_name))
            remote_cmd = CONSTANT.DRS_CMD_SUDO_CHOWN.format(user_name, remote_staging_dir)
            chown_result = self.execute_host_cmd_sudo_root(remote_cmd)
            self.logger.debug("Dir ownership change (chown) result = {}".format(chown_result.stdout.strip()))

        # Execute staged remote script
        # Note that we are using a different user name for execution vs the one used to stage & delete
        remote_cmd = CONSTANT.DRS_CMD_EXECUTE_SCRIPT_FMT.format(remote_staging_dir, interpreter, remote_script_path)
        script_output = self.execute_host_cmd_sudo_user(remote_cmd, user_name, warn)
        self.logger.debug("Script output/result = {}".format(script_output))

        # Delete staged remote directory & all it's contents
        remote_cmd = CONSTANT.DRS_CMD_OPC_RMDIR.format(remote_staging_dir)
        rmdir_result = self.execute_host_cmd_sudo_root(remote_cmd)
        self.logger.debug("Delete directory (rmdir) result = {}".format(rmdir_result.stdout.strip()))

        """
        # Delete staged dependencies
        if deps_list is not None:
            for dep in deps_list:
                remote_script_path = remote_staging_dir + '/' + dep
                remote_cmd = CONSTANT.DRS_CMD_OPC_RM_FILE.format(remote_script_path)
                del_result = self.execute_host_cmd_sudo_user(remote_cmd, self.user_name)
                self.logger.debug("Delete file result = ".format(del_result.stdout.strip()))
        """

        return script_output

    def get_host_osinfo(self):
        """
        Gets the full hostname and local IP address for this host using internal script

        :return: The full hostname (e.g. soahost2.sub0123456.soacsdrvcn.oraclevcn.com)
                The local (private) IP of the host (e.g. 10.0.0.4)
        """

        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_HOST_GET_OSINFO,
                                                      None, None, self.user_name, oraenv=False)

        rxp = r"FULL_HOSTNAME=(.*)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            full_hostname = p.group(1)
        else:
            self.logger.error("ERROR: FAILED to extract hostname.  Output = \n{}".format(result.stdout))
            raise Exception("ERROR: FAILED to extract hostname.")

        self.logger.debug("Extracted Hostname = {}".format(full_hostname))

        rxp = r"IP_ADDRESS=(.*)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            ip_address = p.group(1)
        else:
            self.logger.error("ERROR: FAILED to extract IP address.  Output = \n{}".format(result.stdout))
            raise Exception("ERROR: FAILED to extract IP address")

        self.logger.debug("Extracted IP Address = {}".format(ip_address))

        rxp = r"OS_VERSION=(.*)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            os_version = p.group(1)
        else:
            self.logger.error("ERROR: FAILED to extract OS version.  Output = \n{}".format(result.stdout))
            raise Exception("ERROR: FAILED to extract OS version.")

        self.logger.debug("Extracted OS version = {}".format(os_version))

        return full_hostname, ip_address, os_version

    def reboot_host(self, timeout=660):
        """
        Reboot the specified host and wait for 'timeout' seconds to log back in and verify that reboot succeeded.
        :param timeout: Time to wait (in seconds) for reboot.  Default is 11 minutes (660 seconds).
        :return:  True - if host reboot succeeded.
        :raises:  Exception if the reboot failed.
        """
        self.logger.info("Rebooting host [{}]".format(self.host_ip))

        reboot_cmd = '/usr/sbin/shutdown -r +0'  # reboot immediately
        time_left = timeout

        # result = self.fab_conn.sudo(reboot_cmd, pty=True)
        result = self.execute_host_cmd_sudo_root(reboot_cmd)
        self.logger.debug("Command output = " + result.stdout)

        # wait for node to reboot
        while self.is_connected() is True:
            self.logger.info("Still connected to host")
            time.sleep(2)

        self.logger.info("Disconnected from host. Reboot was successful.")

        while time_left > 0:
            try:
                self.logger.info("Checking if host [{}] is UP after reboot...".format(self.host_ip))
                time.sleep(10)
                self.connect_host(self.host_ip, self.user_name, self.key_file)
                if self.is_connected():
                    self.logger.info("Host [{}] has rebooted and is back online".format(self.host_ip))
                    return True
                else:
                    self.logger.info("Host [{}] has not yet rebooted".format(self.host_ip))
            except Exception as e:
                # Note: The exceptions we catch here are usually non-fatal because the connection attempt times out
                # We just log the exception and keep going until we've exhausted our entire login timeout
                reason = str(e)
                self.logger.info("Caught exception. Reason = [{}]".format(reason))
                time_left -= 30
                self.logger.info("Login attempt failed.  Total retry time left = [{}]".format(time_left))

        raise Exception("ERROR: TIMEOUT! FAILED to reconnect to rebooted host [{}] after [{}] seconds".
                        format(self.host_ip, timeout))


#
#   DRSDatabase
#
class DRSDatabase(object):
    """
    Models an Oracle database object

    NOTE: The reason we are adding an extra encapsulation layer of host functions above the DRSHost object
            is because in the future we may need to deal with the "any host" situation instead of only one host
            If/when that becomes true, the user of the DRSDatabase object does not have to worry about which
            host to use.
    """

    def __init__(self):
        """
        Initializes a DRSDatabase object

        :return: An initialized DRSDatabase object
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.host_list = list()
        self.host_list.append(DRSHost())
        self.id = "[{}::{}]".format(type(self).__name__, id(self))
        self.logger.debug("Created object " + self.id)

    def is_host_connected(self):
        """
        Checks if DB host connection is active/open
        :return: True if connected, else False
        """
        host = self.__get_valid_host()
        return host.is_connected()

    def connect_host(self, host_ip, user_name, key_file):
        """
        Connect to the database host
        :param host_ip:  host IP address
        :param user_name: user name
        :param key_file: full path & name of SSH auth key file

        :return: None
        """
        host = self.__get_valid_host()
        return host.connect_host(host_ip, user_name, key_file)

    def disconnect_host(self):
        """
        Disconnect from the database host

        :return: None
        """
        host = self.__get_valid_host()
        return host.disconnect_host()

    def execute_host_cmd(self, cmd, user_name):
        """
        Executes specified command on database host
        :param cmd: Command to execute
        :param user_name: user name to use when executing cmd
        :return:  The output of the command
        """
        host = self.__get_valid_host()
        return host.execute_host_cmd_sudo_user(cmd, user_name)

    def execute_host_cmd_pty(self, cmd, user_name):
        # For Bug 33748539 (not used)
        """
        Executes specified command on database host
        :param cmd: Command to execute
        :param user_name: user name to use when executing cmd
        :return:  The output of the command
        """
        host = self.__get_valid_host()
        return host.execute_host_cmd_sudo_user_pty(cmd, user_name)

    def copy_local_file_to_db_host(self, local_file, remote_file):
        """
        Copy a local file (usually a script) to the DB host
        :param local_file: full path & name of the local file to copy
        :param remote_file: full path & name of the remote file to copy to

        :return: The output from the executed script
        """
        host = self.__get_valid_host()
        return host.copy_local_file_to_host(local_file, remote_file)

    def execute_internal_script_on_host(self, interpreter, script_name, params, deps, exec_user_name, oraenv, warn=False):
        """
        Wrapper that stages and executes internal script on DB host
        :param interpreter: Script interpreter
        :param script_name: Name of internal script
        :param params: list of params to pass to internal script
        :param deps: list of dependencies for internal script
        :param exec_user_name: user name to use when executing script
        :param oraenv: Whether to source oraenv before executing command ('False' if not specified)

        :return: Output from executed script
        """
        host = self.__get_valid_host()
        return host.execute_internal_script_on_host(interpreter, script_name, params, deps, exec_user_name, oraenv, warn)

    def get_is_db_rac(self, user_name):
        """
        Gets the RAC (cluster) setting for the DB
        :param user_name: user name to use when executing script

        :return: The output of the command
        """

        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_DB_CHECK_IF_RAC,
                                                      None, None, user_name, oraenv=True)
        is_db_rac = result.stdout.strip()
        self.logger.info("Got database RAC cluster setting = {}".format(is_db_rac))

        return is_db_rac

    def get_db_name(self, user_name):
        """
        Gets the name of the database ('db_name')
        :param user_name: user name to use when executing script

        :return: The output of the command
        """

        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_DB_SELECT_DB_NAME,
                                                      None, None, user_name, oraenv=True)
        db_name = result.stdout.strip()
        self.logger.info("Got database name = {}".format(db_name))

        return db_name

    def get_db_unique_name(self, exec_user_name):
        """
        Gets the unique name of the database ('db_unique_name')
        :param exec_user_name: user name to use when executing script

        :return: The output of the command
        """
        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_DB_SELECT_DB_UNIQUE_NAME,
                                                      None, None, exec_user_name, oraenv=True)
        db_unique_name = result.stdout.strip()
        self.logger.info("Got database unique name = {}".format(db_unique_name))

        return db_unique_name

    def verify_data_guard_config(self, DB_CONFIG, db_name, exec_user_name, expected_role, attempts_left=1):
        """
        Verifies that the Data Guard (DG) configuration is correct and the database name passed in
         matches with the expected role in DG configuration output.  Also makes sure there are no other
         DG config errors.
        :param db_name: The name of the database in the DG config
        :param exec_user_name: user name to use when executing script
        :param expected_role: The expected role/state of the database
        :param attempts_left: The number of attempts to try to get a SUCCESS result

        :return: True if the DG configuration is as expected, raises Exception otherwise
        """
        # NOTE: We've implemented a repeat loop here because sometimes the DB status does not show SUCCESS
        # immediately after a role change.  It can take up to 15-20 minutes for WARNINGS to go away.  So we sleep
        # and retry for specified count
        params_list = [DB_CONFIG.sysdba_password]
        sleep_interval = 180  # seconds
        assert attempts_left > 0
        while attempts_left > 0:
            attempts_left -= 1
            result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                          CONSTANT.DRS_SCRIPT_DG_SHOW_CONFIGURATION,
                                                          params_list, None, exec_user_name, oraenv=True)
            dg_output = result.stdout.strip()
            self.logger.debug("Data Guard command output = {}".format(dg_output))

            # Verify that specified DB name in DGMGRL output matches the expected role
            pattern = CONSTANT.DRS_REGEXP_DG_ROLE_DB_NAME.format(db_name, expected_role)
            found = DRSUtil.search_text(pattern, dg_output, ignore_case=True)

            if found is not True:
                raise Exception("ERROR: FAILED to verify that database [{}] current role is [{}]".
                                format(db_name, expected_role))
            else:
                self.logger.info("Verified successfully that database [{}] has current role [{}]".
                                 format(db_name, expected_role))
                self.logger.debug("Data Guard output from script [{}] = \n[{}]".format(
                    CONSTANT.DRS_SCRIPT_DG_SHOW_CONFIGURATION, dg_output))

            # Verify that we see "SUCCESS" string in the output (i.e. "Configuration Status:  SUCCESS")
            pattern = CONSTANT.DRS_REGEXP_DG_CONFIG_STATUS.format("SUCCESS")
            found = DRSUtil.search_text(pattern, dg_output)

            if found is not True:
                if attempts_left == 0:
                    self.logger.error("ERROR: DGMGRL configuration output does NOT show SUCCESS\n{}".format(dg_output))
                    raise Exception("ERROR: DGMGRL configuration output does NOT show SUCCESS")
                else:
                    self.logger.warning("Data Guard output from script [{}] = \n[{}]".format(
                        CONSTANT.DRS_SCRIPT_DG_SHOW_CONFIGURATION, dg_output))

                    self.logger.warning("WARNING: DGMGRL configuration output does not show SUCCESS. ")
                    self.logger.warning("Will re-check again after sleeping for [{}] seconds. [{}] retries left.".
                                        format(sleep_interval, attempts_left))
                    time.sleep(sleep_interval)
            else:
                self.logger.info("DGMGRL configuration output shows SUCCESS".format(db_name))
                break

        return True

    def convert_to_physical_standby(self, DB_PRIM, DB_STBY, exec_user_name):
        """
        Convert the database to a physical database
        :param DB_PRIM: The primary DB config
        :param DB_STBY: The standby DB config
        :param exec_user_name: user name to use when executing script

        :return: True if the DG conversion to physical standby succeeded
        :raises: raises Exception on errors
        """

        params_list = [DB_PRIM.sysdba_password, DB_PRIM.db_unique_name, DB_STBY.db_unique_name]
        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_DG_CONVERT_DB_TO_PHYSICAL_STANDBY,
                                                      params_list, None, exec_user_name, oraenv=True)
        dg_output = result.stdout.strip()
        self.logger.debug("Data Guard command output = ".format(dg_output))

        # Verify that DB was converted successfully
        pattern = CONSTANT.DRS_REGEXP_DG_CONVERT_PHYSICAL_STANDBY.format(DB_STBY.db_unique_name)
        found = DRSUtil.search_text(pattern, dg_output, ignore_case=True)

        if found is not True:
            self.logger.error("ERROR: FAILED to convert database [{}] to PHYSICAL STANDBY.  Data Guard Output = {}".
                              format(DB_STBY.db_unique_name, dg_output))
            raise Exception("ERROR: FAILED to convert database to PHYSICAL STANDBY")
        else:
            self.logger.debug("Data Guard output from script [{}] = \n[{}]".format(
                CONSTANT.DRS_SCRIPT_DG_CONVERT_DB_TO_PHYSICAL_STANDBY, dg_output))
            self.logger.info("Successfully converted database [{}] to PHYSICAL STANDBY".format(DB_STBY.db_unique_name))

        return True

    def convert_to_snapshot_standby(self, DB_PRIM, DB_STBY, exec_user_name):
        """
        Convert the standby database to a snapshot standby database
        :param DB_PRIM: The primary DB config
        :param DB_STBY: The standby DB config
        :param exec_user_name: user name to use when executing script

        :return: True if the DG conversion to snapshot standby succeeded
        :raises: raises Exception on errors
        """

        params_list = [DB_PRIM.sysdba_password, DB_PRIM.db_unique_name, DB_STBY.db_unique_name]
        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_DG_CONVERT_DB_TO_SNAPSHOT_STANDBY,
                                                      params_list, None, exec_user_name, oraenv=True)
        dg_output = result.stdout.strip()
        self.logger.debug("Data Guard command output = ".format(dg_output))

        # Verify that DB was converted successfully
        pattern = CONSTANT.DRS_REGEXP_DG_CONVERT_SNAPSHOT_STANDBY.format(DB_STBY.db_unique_name)
        found = DRSUtil.search_text(pattern, dg_output, ignore_case=True)

        if found is not True:
            self.logger.error("ERROR: FAILED to convert database [{}] to SNAPSHOT STANDBY.  Data Guard Output = {}".
                              format(DB_STBY.db_unique_name, dg_output))
            raise Exception("ERROR: FAILED to convert database to SNAPSHOT STANDBY")
        else:
            self.logger.debug("Data Guard output from script [{}] = \n[{}]".format(
                CONSTANT.DRS_SCRIPT_DG_CONVERT_DB_TO_PHYSICAL_STANDBY, dg_output))
            self.logger.info("Successfully converted database [{}] to SNAPSHOT STANDBY".format(DB_STBY.db_unique_name))

        return True

    def switchover_to_standby(self, DB_PRIM, DB_STBY, exec_user_name):
        """
        Switchover to the standby database
        :param DB_PRIM: The primary DB config
        :param DB_STBY: The standby DB config
        :param exec_user_name: user name to use when executing script

        :return: True if the DB switchover succeeded
        :raises: raises Exception on errors
        """

        params_list = [DB_PRIM.sysdba_password, DB_PRIM.db_unique_name, DB_STBY.db_unique_name]
        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_DG_SWITCHOVER_DB,
                                                      params_list, None, exec_user_name, oraenv=True)
        dg_output = result.stdout.strip()
        self.logger.debug("Data Guard command output = {}".format(dg_output))

        # Verify that DB switchover was successful
        pattern = CONSTANT.DRS_REGEXP_DG_SWITCHOVER_DB.format(DB_STBY.db_unique_name)
        found = DRSUtil.search_text(pattern, dg_output, ignore_case=True)

        if found is not True:
            self.logger.error("ERROR: FAILED to switchover database to [{}].  Data Guard Output = {}".
                              format(DB_STBY.db_unique_name, dg_output))
            raise Exception("ERROR: FAILED to switchover database")
        else:
            self.logger.info("Switchover database successful.  New primary DB is [{}]".format(DB_STBY.db_unique_name))
            self.logger.debug("Data Guard output from script [{}] = \n[{}]".format(
                CONSTANT.DRS_SCRIPT_DG_SWITCHOVER_DB, dg_output))

        return True

    def __get_valid_host(self):
        """
        Internal method that returns a valid host that is up and can be used to execute commands

        NOTE: For now we assume that the first host (0th entry in self.host_list) is always Up & valid to return
        Eventually we may need to fix this where there could be multiple hosts in a RAC cluster and some may be down

        :return: DRSHost object
        """
        return self.host_list[0]
        # TODO: Find and return the correct host if this is a RAC cluster and some hosts are down


#
#   DRSWls
#
class DRSWls(object):
    """
    Models a WebLogic Server object

    NOTE: The reason we are adding an extra encapsulation layer of host functions above the DRSHost object
            is because in the future we may need to deal with the "any host" situation instead of only one host
            If/when that becomes true, the user of the DRSWls object does not have to worry about which
            host to use.
    """

    def __init__(self):
        """
        Initializes a DRSWls object

        :return: An initialized DRSWls object
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.host_list = list()
        self.host_list.append(DRSHost())
        self.id = "[{}::{}]".format(type(self).__name__, id(self))
        self.logger.debug("Created object " + self.id)

    def is_host_connected(self):
        """
        Checks if WLS host connection is active/open
        :return: True if connected, else False
        """
        host = self.__get_valid_host()
        return host.is_connected()

    def connect_host(self, host_ip, user_name, key_file):
        """
        Connect to the WLS host
        :param host_ip:  host IP address
        :param user_name: user name
        :param key_file: full path & name of SSH auth key file

        :return: None
        """
        host = self.__get_valid_host()
        return host.connect_host(host_ip, user_name, key_file)

    def disconnect_host(self):
        """
        Disconnect from the WLS host

        :return: None
        """
        host = self.__get_valid_host()
        return host.disconnect_host()

    def execute_host_cmd(self, cmd, user_name):
        """
        Executes specified command on WLS host
        :param cmd: Command to execute
        :param user_name: user name to use when executing cmd

        :return:  The output of the command
        """
        host = self.__get_valid_host()
        return host.execute_host_cmd_sudo_user(cmd, user_name)

    def copy_local_file_to_wls_host(self, local_file, remote_file):
        """
        Copy a local file (usually a script) to the WLS host
        :param local_file: full path & name of the local file to copy
        :param remote_file: full path & name of the remote file to copy to

        :return: The output from the executed script
        """
        host = self.__get_valid_host()
        return host.copy_local_file_to_host(local_file, remote_file)

    def copy_remote_file_from_host(self, remote_file, local_dir, user_name):
        """
        Copy a file from a remote directory on this WLS host to a local dir
        :param remote_file: full path & name of the remote file to copy
        :param local_dir: the local directory to copy the file to
        :param user_name: user name who owns remote file

        :return: The full path to the copied local file
        """
        host = self.__get_valid_host()
        return host.copy_remote_file_from_host(remote_file, local_dir, user_name)

    def execute_internal_script_on_host(self, interpreter, script_name, params, deps, user_name, oraenv, warn=False):
        """
        Wrapper that stages and executes internal script on WLS host
        :param interpreter: Script interpreter
        :param script_name: Name of internal script
        :param params: List of params to pass to internal script
        :param deps: list of dependencies for internal script
        :param user_name: user name to use when executing script
        :param oraenv: Whether to source oraenv before executing command ('False' if not specified)

        :return: Output from executed script
        """
        host = self.__get_valid_host()
        return host.execute_internal_script_on_host(interpreter, script_name, params, deps, user_name, oraenv, warn)

    def get_wls_domain_home(self, user_name):
        """
        Gets the WLS domain home using internal script
        :param user_name: user name who installed/owns the WLS domain

        :return: The domain home (e.g. /u01/data/domain/wls_home)
        """

        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_WLS_GET_DOMAIN_HOME,
                                                      None, None, user_name, oraenv=True)
        domain_home = result.stdout.strip()
        self.logger.info("Got WLS domain home = {}".format(domain_home))

        return domain_home

    def check_wls_stack_up(self, admin_server_name, managed_server_name, user_name):
        """
        Checks if the specified WLS Admin Server process is running
        :param admin_server_name: name of the admin server
        :param managed_server_name: name of the managed server
        :param user_name: user name for script execution

        :return: True, if stack is up. False, otherwise.
        """

        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_WLS_CHECK_STACK_UP,
                                                      [admin_server_name], None, user_name, oraenv=True)
        result = result.stdout.strip()
        self.logger.info("Check Admin Server result = {}".format(result))

        if 'SUCCESS' in result:
            return True
        else:
            return False

    def get_wls_home(self, user_name):
        """
        Gets the WebLogic Server home using internal script
        :param user_name: user name who installed/owns the WLS domain

        :return: The WLS home (e.g. /u01/app/oracle/middleware/wlserver/server)
        """

        result = self.execute_internal_script_on_host(CONSTANT.DRS_SCRIPT_INTERPRETER_SH,
                                                      CONSTANT.DRS_SCRIPT_WLS_INITINFO_GET_WL_HOME,
                                                      None, None, user_name, oraenv=True)
        wls_home = result.stdout.strip()
        wls_home += '/server'
        self.logger.info("Got WLS home = {}".format(wls_home))

        return wls_home

    def get_wls_domain_config_file_contents(self, domain_config_file_path, user_name):
        """
        Dump (cat) the contents of the WLS domain config file
        :param user_name: user name who installed/owns the WLS domain
        :param domain_config_file_path: full path to the domain config file

        :return: The contents of the WLS domain config file
        """
        wls_get_domain_config_file_cmd = CONSTANT.DRS_CMD_ORACLE_CAT_FILE.format(domain_config_file_path)
        # For Bug 33748539 (not used)
        #cmd_result = self.execute_host_cmd_pty(wls_get_domain_config_file_cmd, user_name)
        cmd_result = self.execute_host_cmd(wls_get_domain_config_file_cmd, user_name)
        self.logger.info("Got contents of WLS domain config file: [{}]".format(domain_config_file_path))

        return cmd_result.stdout

    def get_wls_admin_server_status(self, WLS_CONFIG):
        """
        Get the current state of the admin server

        :param WLS_CONFIG: The WLS site config

        :return:
            'RUNNING' -- the admin server is RUNNING
            'SHUTDOWN' -- the admin server is SHUTDOWN (STOPPED)
            'ERROR' -- there was an ERROR getting the status
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_ADMIN_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_ADMIN_CONTROL_USECASE_STATUS,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_ADMIN_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_NAME + WLS_CONFIG.wlsadm_server_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_TYPE + CONSTANT.DRS_WLS_ADMIN_SERVER_TYPE,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_HOST + WLS_CONFIG.wlsadm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_PORT + WLS_CONFIG.wlsadm_listen_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + WLS_CONFIG.wlsadm_nm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD + WLS_CONFIG.wlsadm_password,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True, warn=True)

        self.logger.debug("WLS Admin Control output = {}".format(result.stdout.strip()))

        rxp = r"ADMIN SERVER STATUS = (.*)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            self.logger.error("WLS Admin Server STATUS check FAILED.  Output = \n{}".format(result.stdout))
            raise Exception("WLS Admin Server STATUS check FAILED!")

        self.logger.info("WLS Admin Server Status = {}".format(status))

        return status

    def get_wls_managed_server_status(self, WLS_CONFIG, server_name, server_host):
        """
        Get the current state of the managed server

        :param WLS_CONFIG: The WLS site config
        :param server_name: The name of the managed server
        :param server_host: The host for the managed server
        :return:
            'RUNNING' -- the admin server is RUNNING
            'SHUTDOWN' -- the admin server is SHUTDOWN (STOPPED)
            'ERROR' -- there was an ERROR getting the status
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_MANAGED_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_MANAGED_CONTROL_USECASE_STATUS,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_MANAGED_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_NAME + server_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_TYPE + CONSTANT.DRS_WLS_MANAGED_SERVER_TYPE,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_HOST + WLS_CONFIG.wlsadm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_PORT + WLS_CONFIG.wlsadm_listen_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + server_host,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD + WLS_CONFIG.wlsadm_password,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True, warn=True)

        self.logger.debug("WLS Managed Control output = {}".format(result.stdout.strip()))

        rxp = r"MANAGED SERVER STATUS = (.*)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            self.logger.error("WLS Managed Server STATUS check failed.  Output = \n{}".format(result.stdout))
            raise Exception("WLS Managed Server STATUS check FAILED!")

        self.logger.info("WLS Managed Server Status = {}".format(status))

        return status

    def get_wls_node_manager_status(self, WLS_CONFIG, nm_host_name):
        """
        Get the current state of the node manager

        :param WLS_CONFIG: The WLS site config
        :param nm_host_name: The host name for the node manager
        :return:
            'RUNNING' -- the node manager is RUNNING
            'SHUTDOWN' -- the node manager is SHUTDOWN (STOPPED)
            'ERROR' -- there was an ERROR getting the status
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_NM_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_NM_CONTROL_USECASE_STATUS,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_NM_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + nm_host_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True)

        self.logger.debug("Node Manager Control output = {}".format(result.stdout.strip()))

        rxp = r"NODE MANAGER STATUS = (.*)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            self.logger.error("Node Manager STATUS check failed.  Output = \n{}".format(result.stdout))
            raise Exception("Node Manager STATUS check FAILED!")

        self.logger.info("Node Manager Status = {}".format(status))

        return status

    def stop_wls_admin_server(self, WLS_CONFIG):
        """
        Stop the admin server

        :param WLS_CONFIG: The WLS site config
        :return:
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_ADMIN_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_ADMIN_CONTROL_USECASE_STOP,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_ADMIN_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_NAME + WLS_CONFIG.wlsadm_server_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_TYPE + CONSTANT.DRS_WLS_ADMIN_SERVER_TYPE,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_HOST + WLS_CONFIG.wlsadm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_PORT + WLS_CONFIG.wlsadm_listen_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + WLS_CONFIG.wlsadm_nm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD + WLS_CONFIG.wlsadm_password,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True, warn=True)

        self.logger.debug("WLS Admin Control output = {}".format(result.stdout.strip()))

        """
        rxp = r"ADMIN SERVER STATUS = (.*state)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            raise Exception("WLS Admin Server STOP failed.  Output = \n{}".format(result.stdout))
        """
        if "SHUTDOWN" in result.stdout and 'ERROR' not in result.stdout:
            self.logger.info("WLS Admin Server STOP Result = SHUTDOWN")
        elif "FAILED_NOT_RESTARTABLE" in result.stdout:
           self.logger.info("WLS Admin Server STOP Result = FAILED_NOT_RESTARTABLE, continuing execution")
        elif "UNKNOWN" in result.stdout:
           self.logger.info("WLS Admin Server STOP Result = UNKNOWN, continuing execution")
        else:
            self.logger.error("WLS Admin Server STOP failed.  Output = \n{}".format(result.stdout))
            raise Exception("WLS Admin Server STOP FAILED!")

    def start_wls_admin_server(self, WLS_CONFIG):
        """
        Start the admin server

        :param WLS_CONFIG: The WLS site config
        :return:
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_ADMIN_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_ADMIN_CONTROL_USECASE_START,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_ADMIN_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_NAME + WLS_CONFIG.wlsadm_server_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_TYPE + CONSTANT.DRS_WLS_ADMIN_SERVER_TYPE,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_HOST + WLS_CONFIG.wlsadm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_PORT + WLS_CONFIG.wlsadm_listen_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + WLS_CONFIG.wlsadm_nm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD + WLS_CONFIG.wlsadm_password,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True)

        self.logger.debug("WLS Admin Control output = {}".format(result.stdout.strip()))

        """
        rxp = r"ADMIN SERVER STATUS = (.*state)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            self.logger.error("WLS Admin Server START failed.  Output = \n{}".format(result.stdout))
            raise Exception("WLS Admin Server START FAILED!")

        """

        if "RUNNING" in result.stdout and 'ERROR' not in result.stdout:
            self.logger.info("WLS Admin Server START Result = RUNNING")
        else:
            self.logger.error("WLS Admin Server START failed.  Output = \n{}".format(result.stdout))
            raise Exception("WLS Admin Server START FAILED!")

    def start_wls_managed_server(self, WLS_CONFIG, server_name, server_host):
        """
        Start the managed server

        :param WLS_CONFIG: The WLS site config
        :param server_name: The name of the managed server
        :param server_host: The host for the managed server
        :return:
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_MANAGED_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_MANAGED_CONTROL_USECASE_START,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_MANAGED_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_NAME + server_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_TYPE + CONSTANT.DRS_WLS_MANAGED_SERVER_TYPE,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_HOST + WLS_CONFIG.wlsadm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_PORT + WLS_CONFIG.wlsadm_listen_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + server_host,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD + WLS_CONFIG.wlsadm_password,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True)

        self.logger.debug("WLS Managed Control output = {}".format(result.stdout.strip()))

        """
        rxp = r"STATUS >>> (.*state)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            self.logger.error("WLS Manager Server START failed.  Output = \n{}".format(result.stdout))
            raise Exception("WLS Manager Server START FAILED!")

        """
        if "RUNNING" in result.stdout and 'ERROR' not in result.stdout:
            self.logger.info("WLS Managed Server [{}] START Result = RUNNING".format(server_name))
        else:
            self.logger.error("WLS Managed Server [{}] START failed.  Output = \n{}".format(server_name, result.stdout))
            raise Exception("WLS Managed Server START FAILED!")

    def stop_wls_managed_server(self, WLS_CONFIG, server_name, server_host):
        """
        Stop the managed server

        :param WLS_CONFIG: The WLS site config
        :param server_name: The name of the managed server
        :param server_host: The host for the managed server
        :return:
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_MANAGED_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_MANAGED_CONTROL_USECASE_STOP,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_MANAGED_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_NAME + server_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_SERVER_TYPE + CONSTANT.DRS_WLS_MANAGED_SERVER_TYPE,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_HOST + WLS_CONFIG.wlsadm_hostname,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_ADMIN_PORT + WLS_CONFIG.wlsadm_listen_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + server_host,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD + WLS_CONFIG.wlsadm_password,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                               CONFIG.GENERAL.ora_user_name, oraenv=True, warn=True)

        if "SHUTDOWN" in result.stdout and 'ERROR' not in result.stdout:
           self.logger.info("WLS Managed Server [{}] STOP Result = SHUTDOWN".format(server_name))
        elif "FAILED_NOT_RESTARTABLE" in result.stdout:
           self.logger.info("WLS Managed Server [{}] STOP Result = FAILED_NOT_RESTARTABLE, continuing execution".format(server_name))
        elif "UNKNOWN" in result.stdout:
           self.logger.info("WLS Managed Server [{}] STOP Result = UNKNOWN, continuing execution".format(server_name))
        else:
            self.logger.error("WLS Managed Server [{}] STOP failed.  Output = \n{}".format(server_name, result.stdout))
            raise Exception("WLS Managed Server STOP FAILED!")


        self.logger.debug("WLS Managed Control output = {}".format(result.stdout.strip()))

    def start_wls_node_manager(self, WLS_CONFIG, nm_host_name):
        """
        Start the node manager

        :param WLS_CONFIG: The WLS site config
        :param nm_host_name: The host for the node manager
        :return:
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_NM_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_NM_CONTROL_USECASE_START,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_NM_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + nm_host_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True)

        self.logger.debug("WLS Managed Control output = {}".format(result.stdout.strip()))

        """
        rxp = r"STATUS >>> (.*state)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            raise Exception("WLS Manager Server START failed.  Output = \n{}".format(result.stdout))
        """

        if "NM_RUNNING" in result.stdout and 'ERROR' not in result.stdout:
            self.logger.info("Node Manager START Result = NM_RUNNING")
        else:
            self.logger.error("Node Manager START failed.  Output = \n{}".format(result.stdout))
            raise Exception("Node Manager START FAILED!")

    def stop_wls_node_manager(self, WLS_CONFIG, nm_host_name):
        """
        Stop the node manager

        :param WLS_CONFIG: The WLS site config
        :param nm_host_name: The host for the node manager
        :return:
        """
        wlst_path = WLS_CONFIG.mw_home + CONSTANT.DRS_SCRIPT_INTERPRETER_WLST
        internal_script = CONSTANT.DRS_SCRIPT_WLS_NM_CONTROL
        deps_list = [CONSTANT.DRS_SCRIPT_WLS_UTIL]
        param_list = [
            CONSTANT.DRS_WLS_SCRIPT_PARAM_USE_CASE + CONSTANT.DRS_WLS_NM_CONTROL_USECASE_STOP,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_TIMEOUT + CONSTANT.DRS_WLS_NM_CONTROL_TIMEOUT,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_WLS_HOME + WLS_CONFIG.wls_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_MW_HOME + WLS_CONFIG.mw_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME + WLS_CONFIG.domain_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR + WLS_CONFIG.domain_home,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_HOST + nm_host_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PORT + WLS_CONFIG.wlsadm_nm_port,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE + WLS_CONFIG.wlsadm_nm_type,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_USER + WLS_CONFIG.wlsadm_user_name,
            CONSTANT.DRS_WLS_SCRIPT_PARAM_NM_PASSWORD + WLS_CONFIG.wlsadm_password,
        ]

        result = self.execute_internal_script_on_host(wlst_path, internal_script, param_list, deps_list,
                                                      CONFIG.GENERAL.ora_user_name, oraenv=True)

        self.logger.debug("WLS Managed Control output = {}".format(result.stdout.strip()))

        """
        rxp = r"STATUS >>> (.*state)"
        p = re.search(rxp, result.stdout)
        if p is not None:
            status = p.group(1)
        else:
            raise Exception("Node Manager STOP failed.  Output = \n{}".format(result.stdout))
        """

        if "NM_NOT_RUNNING" in result.stdout and 'ERROR' not in result.stdout:
            self.logger.info("Node Manager STOP Result = NM_NOT_RUNNING")
        else:
            self.logger.error("Node Manager STOP failed.  Output = \n{}".format(result.stdout))
            raise Exception("Node Manager STOP FAILED!")

    def get_admin_host(self):
        """
        Method that returns the admin host for this WLS

        :return: DRSHost object
        """
        return self.host_list[0]

    def __get_valid_host(self):
        """
        Internal method that returns a valid host that is up and can be used to execute commands

        NOTE: For now we assume that the first host (0th entry in self.host_list) is always Up & valid to return
        Eventually we may need to fix this where there could be multiple hosts in a RAC cluster and some may be down

        :return: DRSHost object
        """
        return self.host_list[0]


#
#   DRSUtil
#
class DRSUtil(object):
    """
    Util class which implements utility functions (many are static)

    """

    def __init__(self):
        """
        Initializes a DRSUtil object

        :return: A DRSUtil object with logging initialized
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.id = "[{}::{}]".format(type(self).__name__, id(self))
        self.logger.debug("Created object " + self.id)

    @staticmethod
    def search_text(pattern, text, ignore_case=False):
        """
        Searches for a regexp pattern in a text fragment.  Used for pattern matching text.
        :param pattern: A regular expression pattern to look for
        :param text: The text buffer to search
        :param ignore_case: Flag indicating whether the string match should ignore case

        :return: True if the pattern was found, False otherwise
        """
        if ignore_case is True:
            r = re.compile(pattern, re.IGNORECASE)
        else:
            r = re.compile(pattern)

        m = r.search(text)
        if m is not None:
            return True
        else:
            return False

    @staticmethod
    def extract_text(pattern, text):
        """
        Extracts a regexp pattern in a text fragment.
        For example:
            if you want to extract 'foobar' from the string: "Some text before : foobar : plus some text after"
            the "pattern" parameter you should pass in should be: "Some text before : (.*) : plus some text after"

        :param pattern: A regular expression with an embedded pattern to look for
        :param text: The text buffer to search

        :return: The substring matching the embedded pattern
        """
        p = re.search(pattern, text)

        if p is not None:
            return p.group
        else:
            return None

    @staticmethod
    def generate_unique_filename():
        """
        Generates a temporary directory name that includes a timestamp and random string
        :return: The directory name
        """
        rand_ascii_string = ''.join(choice(ascii_uppercase) for i in range(8))
        time_stamp = datetime.now().strftime('%Y%m%d%H%M%S')
        file_name = 'DRS-' + str(time_stamp) + '-' + str(rand_ascii_string)

        return file_name

    @staticmethod
    def dump_object(obj):
        for attr in dir(obj):
            print("obj.%s = %r" % (attr, getattr(obj, attr)))

    @staticmethod
    def test_config_object_fully_initialized(obj):
        for key, value in obj.__dict__.items():
            if key.startswith('__'):
                continue  # skip this var, it's not ours
            else:
                if value is None:
                    raise Exception("Configuration Key[{}] in Object:[{}] from Module:[{}] is not initialized".
                                    format(key, obj.__name__, obj.__module__))

    @staticmethod
    def check_dict_no_empty_values(d, missing):
        """
        Check that the configuration dictionary has no empty config values
        :param d: the dict to check
        :param missing: fill in with list of keys that have empty values
        :return:
        """
        for k, v in d.items():
            if isinstance(v, dict):
                DRSUtil.check_dict_no_empty_values(v, missing)
            else:
                if not v:
                    missing.append(k)

    @staticmethod
    def log_header(l, msg):
        l.info("\n\n" + "#"*80 + "\n" + "####" + msg.center(76) + "\n" + "#"*80 + "\n")
