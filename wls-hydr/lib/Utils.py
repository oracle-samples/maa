#!/usr/bin/python3

import os
import re
import string
import ipaddress

class Constants:
    BASEDIR = os.path.abspath(f"{os.path.dirname(os.path.realpath(__file__))}/..")
    EXTERNAL_CONFIG_FILE = f"{BASEDIR}/config/replication.properties"
    INTERNAL_CONFIG_FILE = f"{BASEDIR}/lib/replication.internals"
    OCI_ENV_FILE = f"{BASEDIR}/config/oci.env"
    PREM_ENV_FILE = f"{BASEDIR}/config/prem.env"
    DISCOVERY_SCRIPT = f"{BASEDIR}/lib/Discovery.py"
    REPLICATION_SCRIPT = f"{BASEDIR}/lib/DataReplication.py"
    PROVISIONING_SCRIPT = f"{BASEDIR}/wls_hydr.py"
    CLEANUP_SCRIPT = f"{BASEDIR}/cleanup.py"

    DIRECTORIES_CFG_TAG = "DIRECTORIES"
    OCI_CFG_TAG = "OCI_ENV"
    PREM_CFG_TAG = "PREM_ENV"
    OPTIONS_CFG_TAG = 'OPTIONS'
    DISCOVERY_RESULTS_FILE = f"{BASEDIR}/config/discovery_results.csv"
    TNS_TAG = "JDBC" 

class Status:
    CREATED = 'CREATED'
    PREEXISTING = 'PREEXISTING'
    DELETED = 'DELETED'
    FAILED_DELETE = 'FAILED TO DELETE'

class Utils:
    @staticmethod
    def validate_ip(ip):
        try:
            _ = ipaddress.ip_address(ip)
            return True
        except ValueError:
            return False

    @staticmethod  
    def validate_hostname(hostname):
        # max 63 characters
        if len(hostname) > 63 or len(hostname) < 1:
            return False
        # hostname cannot be all numbers
        if re.match(r"[0-9]+$", hostname):
            return False
        # hyphens aren't allowed at the beginning or end
        if hostname[0] == "-" or hostname[-1] == "-":
            return False
        # RFCs 952 and 1123
        allowed = re.compile(r"^[a-z0-9-]*$", re.IGNORECASE)
        return bool(allowed.match(hostname))
    
    @staticmethod
    def validate_label(label):
        # max 15 characters
        if len(label) > 15 or len(label) < 1:
            return False
        # first character must be letter
        if label[0] not in string.ascii_letters:
            return False
        # only alphanumeric
        allowed = re.compile(r"^[a-z0-9]*$", re.IGNORECASE)
        return bool(allowed.match(label))
    
    @staticmethod
    def validate_name(name):
        pattern = r'^[a-zA-Z0-9-_]*$'
        if re.match(pattern, name):
            return True
        return False
    
    @staticmethod
    def validate_path(path):
        if not isinstance(path, str):
            return False
        if path[0] != "/":
            return False
        if any(sbstr == "" for sbstr in path.split("/")[1:]):
            return False
        pattern = r'^[a-zA-Z0-9-_/.]*$'
        if re.match(pattern, path):
            return True
        return False
    
    @staticmethod
    def validate_port(port):
        try:
            port = int(port)
        except ValueError:
            return False
        if port < 1 or port > 65535:
            return False
        return True
    
    @staticmethod
    def validate_int(val):
        try:
            int(val)
        except ValueError:
            return False
        return True
    
    @staticmethod
    def validate_yesno(value):
        if value not in ["Yes", "No"]:
            return False
        return True
    
    @staticmethod
    def validate_str(val):
        if len(val) == 0:
            return False
        if not isinstance(val, str):
            return False
        return True
    
    @staticmethod
    def validate_cidr(cidr):
        try:
            octs, bit = cidr.split("/")
            bit = int(bit)
        except (AttributeError, ValueError):
            return False
        if 0 > bit or 31 <= bit:
            return False
        return Utils.validate_ip(octs)

    @staticmethod
    def validate_ocpu(val):
        try:
            int(val)
        except ValueError:
            return False
        if int(val) < 1 or int(val) > 114:
            return False
        return True
    
    @staticmethod
    def validate_fqdn(fqdn):
        pattern  = r"(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)"
        if re.match(pattern, fqdn):
            return True
        return False

    
    @staticmethod
    def validate_opt(value):
        """Function that always returns True. Used for skipping validation of 
        optional values that will later be validated manually. 

        Args:
            value (any): Any value

        Returns:
            bool: always True
        """ 
        return True
    
    @staticmethod
    def validate_by_type(type, value):
        if type == "label":
            return Utils.validate_label(value)
        elif type == "name":
            return Utils.validate_name(value)
        elif type == "hostname":
            return Utils.validate_hostname(value)
        elif type == "ip":
            return Utils.validate_ip(value)
        elif type == "path":
            return Utils.validate_path(value)
        elif type == "port":
            return Utils.validate_port(value)
        elif type == "int":
            return Utils.validate_int(value)
        elif type == "opt":
            return Utils.validate_opt(value)
        elif type == "yesno":
            return Utils.validate_yesno(value)
        elif type == "str":
            return Utils.validate_str(value)
        elif type == "cidr":
            return Utils.validate_cidr(value)
        elif type == "fqdn":
            return Utils.validate_fqdn(value)
        elif type == "ocpu":
            return Utils.validate_ocpu(value)
        else:
            # TODO: placeholder for unimplemented type - FIX THIS
            return True

    @staticmethod
    def validate_config(config, validation_type, primary, standby):
        valid = True
        errors = []
        PRIMARY = primary
        STANDBY = standby
        MANDATORY_KEYS = {
            Constants.DIRECTORIES_CFG_TAG: [
                'WLS_PRODUCTS',
                'WLS_PRIVATE_CONFIG_DIR',
                'WLS_CONFIG_PATH',
                'STAGE_GOLD_COPY_BASE',
                'STAGE_WLS_PRODUCTS',
                'STAGE_WLS_PRODUCTS1',
                'STAGE_WLS_PRODUCTS2',
                'STAGE_WLS_SHARED_CONFIG_DIR',
                'STAGE_WLS_PRIVATE_CONFIG_DIR',
                'STAGE_WLS_VAR'
            ],
            Constants.OPTIONS_CFG_TAG: [
                'delete',
                'rsync_retries',
                'exclude_wls_private_config',
                'exclude_wls_shared_config'
            ]
        }
        if validation_type in ['pull', 'lifecycle', 'tnsnames']:
            MANDATORY_KEYS.update({
                PRIMARY: [
                'wls_osuser',
                'wls_osgroup',
                'wls_ssh_key',
                'wls_nodes'                
                ]
            })
        if validation_type in ['push', 'lifecycle', 'tnsnames']:
            MANDATORY_KEYS.update({
                STANDBY: [
                'wls_osuser',
                'wls_osgroup',
                'wls_ssh_key',
                'wls_nodes'                
                ]
            })
        if validation_type == 'tnsnames':
            MANDATORY_KEYS.update({
                Constants.TNS_TAG: [
                'TNSNAMES_PATH',
                'PREM_SERVICE_NAME',
                'PREM_SCAN_ADDRESS',
                'OCI_SERVICE_NAME',
                'OCI_SCAN_ADDRESS'
                ]
            })
        # check that all expected items are present in cofig file
        for section, items in MANDATORY_KEYS.items():
            if not config.has_section(section):
                valid = False
                errors.append(f"Section {section} is missing from config file")
            for item in items:
                if not config.has_option(section, item):
                    valid = False
                    errors.append(f"Item {item} missing from section {section}")
        # check that all items have a value
        try:
            for section in MANDATORY_KEYS.keys():
                for item in MANDATORY_KEYS[section]:
                    # only exclude lists can be empty
                    if not item.startswith("exclude") and not config[section][item]:
                        valid = False
                        errors.append(f"{item.upper()} value cannot be empty in section {section}")  

        except Exception as e:
            valid = False
            errors.append(str(e))
        # return now because items are missing and we might end up trying to check a missing value later on
        if not valid:
            return valid, errors
        
        if validation_type in ['pull', 'lifecycle', 'tnsnames']:
            primary_ohs_nodes = config[PRIMARY]['ohs_nodes'].split("\n") if config[PRIMARY]['ohs_nodes'] else []
            primary_wls_nodes = config[PRIMARY]['wls_nodes'].split("\n")
            # check that we have at least 2 wls and 2 ohs nodes if ohs is used
            if len(primary_ohs_nodes) < 2 and len(primary_ohs_nodes) != 0:
                valid = False
                errors.append(f"A minimum of 2 primary OHS nodes required - [{len(primary_ohs_nodes)}] present in config file")
            if len(primary_wls_nodes) < 2:
                valid = False
                errors.append(f"A minimum of 2 primary WLS nodes required - [{len(primary_wls_nodes)}] present in config file")
            for ip in primary_ohs_nodes:
                if not Utils.validate_ip(ip):
                    valid = False
                    errors.append(f"Primary OHS node IP [{ip}] is invalid")
            for ip in primary_wls_nodes:
                if not Utils.validate_ip(ip):
                    valid = False
                    errors.append(f"Primary WLS node IP [{ip}] is invalid")
            if len(primary_ohs_nodes) != 0:
                if not os.path.isfile(config[PRIMARY]['ohs_ssh_key']):
                    valid = False
                    errors.append(f"Primary OHS private key file [{config[PRIMARY]['ohs_ssh_key']}] does not exist")
                else:
                    ohs_key_perms = os.stat(config[PRIMARY]['ohs_ssh_key'])
                    ohs_key_perms = oct(ohs_key_perms.st_mode)[-3:]
                    if ohs_key_perms != '600':
                        valid = False
                        errors.append(f"Primary OHS private key file [{config[PRIMARY]['ohs_ssh_key']}] has incorrect premissions: [{ohs_key_perms}] as opposed to [600]")
            if not os.path.isfile(config[PRIMARY]['wls_ssh_key']):
                valid = False
                errors.append(f"Primary WLS private key file [{config[PRIMARY]['ohs_ssh_key']}] does not exist")
            else:
                wls_key_perms = os.stat(config[PRIMARY]['wls_ssh_key'])
                wls_key_perms = oct(wls_key_perms.st_mode)[-3:]
                if wls_key_perms != '600':
                    valid = False
                    errors.append(f"Primary WLS private key file [{config[PRIMARY]['wls_ssh_key']}] has incorrect premissions: [{wls_key_perms}] as opposed to [600]")

        if validation_type in ['push', 'lifecycle', 'tnsnames']:
            standby_ohs_nodes = config[STANDBY]['ohs_nodes'].split("\n") if config[STANDBY]['ohs_nodes'] else []
            standby_wls_nodes = config[STANDBY]['wls_nodes'].split("\n")
            if len(standby_ohs_nodes) < 2 and len(standby_ohs_nodes) != 0:
                valid = False
                errors.append(f"A minimum of 2 standby OHS nodes required - [{len(standby_ohs_nodes)}] present in config file")
            if len(standby_wls_nodes) < 2:
                valid = False
                errors.append(f"A minimum of 2 standby WLS nodes required - [{len(standby_wls_nodes)}] present in config file")
            for ip in standby_ohs_nodes:
                if not Utils.validate_ip(ip):
                    valid = False
                    errors.append(f"Standby OHS node IP [{ip}] is invalid")
            for ip in standby_wls_nodes:
                if not Utils.validate_ip(ip):
                    valid = False
                    errors.append(f"Standby WLS node IP [{ip}] is invalid")
            if len(standby_ohs_nodes) != 0:
                if not os.path.isfile(config[STANDBY]['ohs_ssh_key']):
                    valid = False
                    errors.append(f"Standby OHS private key file [{config[STANDBY]['ohs_ssh_key']}] does not exist")
                else:
                    ohs_key_perms = os.stat(config[STANDBY]['ohs_ssh_key'])
                    ohs_key_perms = oct(ohs_key_perms.st_mode)[-3:]
                    if ohs_key_perms != '600':
                        valid = False
                        errors.append(f"Standby OHS private key file [{config[STANDBY]['ohs_ssh_key']}] has incorrect premissions: [{ohs_key_perms}] as opposed to [600]")
            if not os.path.isfile(config[STANDBY]['wls_ssh_key']):
                valid = False
                errors.append(f"Standby WLS private key file [{config[STANDBY]['wls_ssh_key']}] does not exist")
            else:
                wls_key_perms = os.stat(config[STANDBY]['wls_ssh_key'])
                wls_key_perms = oct(wls_key_perms.st_mode)[-3:]
                if wls_key_perms != '600':
                    valid = False
                    errors.append(f"Standby WLS private key file [{config[STANDBY]['wls_ssh_key']}] has incorrect premissions: [{wls_key_perms}] as opposed to [600]")

        if validation_type == 'lifecycle':
            if len(primary_ohs_nodes) != len(standby_ohs_nodes):
                valid = False
                errors.append("Number of primary OHS nodes does not match standby OHS nodes")
            if len(primary_wls_nodes) != len(standby_wls_nodes):
                valid = False
                errors.append("Number of primary WLS nodes does not match standby WLS nodes")
        return valid, errors

    @staticmethod
    def update_config(config, new_values):
        for section in new_values.sections():
            for key, value in new_values.items(section):
                if config.has_option(section, key):
                    config[section][key] += f"\n{value}"
                else:
                    if section not in config.sections():
                        config.add_section(section)
                    config[section][key] = value
        return config
    
    @staticmethod
    def confirm(prompt):
        while True:
            print(f"{prompt} (yes/no)")
            print("-> ", end="")
            choice = input().strip().lower()
            if choice in ["yes", "y"]:
                return True
            elif choice in ["no", "n"]:
                return False
            else:
                print("Invalid choice. Please enter yes/y or no/n")

    @staticmethod
    def get_user_input(prompt, help="", value_type=""):
        separator_width = max(max([len(line.strip()) for line in prompt.split("\n")]),
                            max([len(line.strip()) for line in help.split("\n")]),
                            len(help.split("\n")[0].strip()) + 6)
        print(f"\n{'-' * separator_width}\n{prompt}")
        if help.strip():
            print("*" * separator_width)
            print(f"Help: {help}")
        print("*" * separator_width)
        valid_input = False
        while not valid_input:
            user_input = input("-> ").strip().lower()
            if not user_input:
                print("Please provide a value")
                continue
            if value_type.strip():
                if not Utils.validate_by_type(value_type, user_input):
                    print(f"Value provided [{user_input}] is invalid.")
                    continue
            valid_input = True
        return user_input

    @staticmethod
    def pprint_arr_table(header, values, r_pad=3):
        """Pretty print a list of lists as a table

        Args:
            header (list): List of header items
            values (list[list]): A list of lists of values to populate the table
            r_pad (int, optional): Right padding offset for each cell. Defaults to 3.

        Raises:
            TypeError: If the header parameter is not a list or if the values parameter 
                not a list of lists.
            ValueError: If the length of the header list or the lengths of any values 
                list differ.
        """
        if type(header) != list:
            raise TypeError("header parameter must be a list")
        if any(type(x) != list for x in values):
            raise TypeError("values parameter must be a list of lists")
        error = ""
        if any([len(x) != len(values[0]) for x in values]):
            error = "values contains different length lists"
        if any([len(header) != len(x) for x in values]):
            if error:
                error += " and header is of different length"
            else:
                error = "header and lists in values must have same number of items"
        if error:
            raise ValueError(error)
        width_offset = r_pad
        width = [0] * len(header)
        for i in range(len(width)):
            width[i] = max([len(x[i]) for x in values + [header]]) + width_offset 
        border = sum(width) + len(values[0]) * 2
        print("=" * border)
        for i in range(len(header)):
            if i == len(header) - 1:
                cell_width = width[i] - 1
            else:
                cell_width = width[i]
            print(f"| {header[i]: <{cell_width}}", end="")
        print("|")
        print("=" * border)
        for item in values:
            for i in range(len(item)):
                if i == len(item) - 1:
                    cell_width = width[i] - 1
                else:
                    cell_width = width[i]
                print(f"| {item[i]: <{cell_width}}", end="")
            print("|")
            print("-" * border)



