# -*- coding: utf-8 -*-
"""
    MAA DR Setup and Configuration Constants.
"""
__author__ = "Oracle "
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """

try:
    import logging
except ImportError:
    print("ERROR: Could not import python's loggin module")
    logging = None
    exit(-1)


class DRS_CONSTANTS:
    # LOGGING
    DRS_LOGFILE_NAME_PREFIX = 'logfile'
    DRS_LOGFILE_NAME = DRS_LOGFILE_NAME_PREFIX + "_%Y%m%d-%H%M%S.log"
    # DRS_LOGFILE_STATEMENT_FORMAT = '%(asctime)s [%(levelname)-7.7s] [%(module)-12.12s::%(lineno)-6.6s]  %(message)s'
    # DRS_LOGFILE_STATEMENT_FORMAT = '%(asctime)s [%(levelname)s] [%(module)s::%(lineno)s] %(message)s'
    DRS_LOGFILE_STATEMENT_FORMAT = \
        '[%(asctime)s] [%(levelname)s] [%(module)s::%(lineno)s][%(name)s::%(funcName)s()] %(message)s'
    DRS_LOGGING_DEFAULT_LOG_LEVEL = logging.DEBUG
    DRS_LOGFILE_LOG_LEVEL = logging.DEBUG
    DRS_STDOUT_LOG_LEVEL = logging.INFO

    # USER CONFIGURATION
    DRS_USER_CONFIG_FILE = './drs_user_config.yaml'

    # CONFIGURATION KEYS

    #  =====  LOCAL DIRECTORIES
    DRS_LOCAL_TEMP_DIRECTORY = '.'
    DRS_WLS_CONFIG_FILE_RELATIVE_PATH_NAME = '/config/config.xml'

    #  =====  INTERNAL SCRIPT PATHS
    DRS_REMOTE_SCRIPT_STAGING_DIR = '/tmp'
    DRS_INTERNAL_SCRIPT_DIR = './_internal_scripts'
    DRS_INTERNAL_TEMP_DIR = './_internal_temp'

    #  =====  SCRIPT INTERPRETERS
    DRS_SCRIPT_INTERPRETER_SH = '/bin/sh'
    DRS_SCRIPT_INTERPRETER_WLST = '/oracle_common/common/bin/wlst.sh'

    #  =====  HOST SCRIPTS
    DRS_SCRIPT_HOST_GET_OSINFO = 'host_get_osinfo.sh'
    DRS_SCRIPT_HOST_CHECK_PS_PROCESS = 'host_check_ps_process.sh'

    #  =====  DATABASE SCRIPTS
    DRS_SCRIPT_DB_SELECT_DB_NAME = 'db_select_db_name.sh'
    DRS_SCRIPT_DB_SELECT_DB_UNIQUE_NAME = 'db_select_db_unique_name.sh'
    DRS_SCRIPT_DB_CHECK_IF_RAC = 'db_check_if_rac.sh'
    DRS_SCRIPT_DG_SHOW_CONFIGURATION = 'dg_show_configuration_verbose.sh'
    DRS_SCRIPT_DG_CONVERT_DB_TO_PHYSICAL_STANDBY = 'dg_convert_db_to_physical_standby.sh'
    DRS_SCRIPT_DG_CONVERT_DB_TO_SNAPSHOT_STANDBY = 'dg_convert_db_to_snapshot_standby.sh'
    DRS_SCRIPT_DG_SWITCHOVER_DB = 'dg_switchover_to_standby_db.sh'

    #  =====  WLS SCRIPTS
    DRS_SCRIPT_WLS_GET_DOMAIN_HOME = 'wls_get_domain_home.sh'
    #DRS_SCRIPT_WLS_GET_WLS_HOME_PS = 'wls_get_wls_home_ps.sh'
    DRS_SCRIPT_WLS_INITINFO_GET_WL_HOME = 'wls_initinfo_get_wl_home.sh'
    DRS_SCRIPT_WLS_CHECK_STACK_UP = 'wls_check_stack_up.sh'
    DRS_SCRIPT_WLS_ADMIN_CONTROL = 'wls_admin_control.py'
    DRS_SCRIPT_WLS_MANAGED_CONTROL = 'wls_managed_control.py'
    DRS_SCRIPT_WLS_NM_CONTROL = 'wls_nm_control.py'
    DRS_SCRIPT_WLS_UTIL = 'wls_util.py'

    #  =====  FMW DR SCRIPTS
    DRS_SCRIPT_FMW_DR_SETUP_PRIMARY = 'fmw_dr_setup_primary.sh'
    DRS_SCRIPT_FMW_DR_SETUP_STANDBY = 'fmw_dr_setup_standby.sh'
    DRS_SCRIPT_FMW_PRIMARY_CHECK_DB_CONNECTIVITY = 'fmw_primary_check_db_connectivity.sh'
    DRS_SCRIPT_FMW_STANDBY_CHECK_DB_CONNECTIVITY = 'fmw_standby_check_db_connectivity.sh'
    DRS_SCRIPT_FMW_PRIMARY_CHECK_CONNECTIVITY_TO_STANDBY_ADMIN = 'fmw_primary_check_connectivity_to_stby_admin.sh'
    #v13
    DRS_SCRIPT_FMW_CHECK_FRONTEND_NAME = 'check_frontend.sh'
    #v14
    DRS_SCRIPT_POST_SETUP_DROP_TMP_INFO = 'post_setup_drop_tmp_info.sh'

    #  =====  SOA SCRIPTS
    DRS_SCRIPT_SOA_INFRA_CHECK = 'check_soainfra.sh'

    #  =====  WLS SCRIPT PARAM KEYWORDS
    DRS_WLS_SCRIPT_PARAM_USE_CASE = 'USE_CASE='
    DRS_WLS_SCRIPT_PARAM_TIMEOUT = 'TIMEOUT='
    DRS_WLS_SCRIPT_PARAM_WLS_HOME = 'WLS_HOME='
    DRS_WLS_SCRIPT_PARAM_MW_HOME = 'MW_HOME='
    DRS_WLS_SCRIPT_PARAM_DOMAIN_NAME = 'DOMAIN_NAME='
    DRS_WLS_SCRIPT_PARAM_DOMAIN_DIR = 'DOMAIN_DIR='
    DRS_WLS_SCRIPT_PARAM_SERVER_NAME = 'SERVER_NAME='
    DRS_WLS_SCRIPT_PARAM_SERVER_TYPE = 'SERVER_TYPE='
    DRS_WLS_SCRIPT_PARAM_ADMIN_HOST = 'ADMIN_HOST='
    DRS_WLS_SCRIPT_PARAM_ADMIN_PORT = 'ADMIN_PORT='
    DRS_WLS_SCRIPT_PARAM_NM_HOST = 'NM_HOST='
    DRS_WLS_SCRIPT_PARAM_NM_PORT = 'NM_PORT='
    DRS_WLS_SCRIPT_PARAM_NM_CONNECT_TYPE = 'NM_CONNECT_TYPE='
    DRS_WLS_SCRIPT_PARAM_WLS_USER = 'WLS_USER='
    DRS_WLS_SCRIPT_PARAM_WLS_PASSWORD = 'WLS_PASSWORD='
    DRS_WLS_SCRIPT_PARAM_NM_USER = 'NM_USER='
    DRS_WLS_SCRIPT_PARAM_NM_PASSWORD = 'NM_PASSWORD='

    #  =====  WLS ADMIN CONTROL PARAMS
    DRS_WLS_ADMIN_CONTROL_USECASE_STATUS = 'ADMIN_SERVER_STATUS'
    DRS_WLS_ADMIN_CONTROL_USECASE_START = 'ADMIN_SERVER_START'
    DRS_WLS_ADMIN_CONTROL_USECASE_STOP = 'ADMIN_SERVER_STOP'
    DRS_WLS_ADMIN_CONTROL_TIMEOUT = '1200'
    DRS_WLS_ADMIN_SERVER_TYPE = 'AdminServer'
    DRS_WLS_ADMIN_DEFAULT_LISTEN_PORT = '7001'
    #DRS_WLS_ADMIN_SERVER_NAME_SUFFIX = 'adminserver'

    #  =====  WLS MANAGED CONTROL PARAMS
    DRS_WLS_MANAGED_CONTROL_USECASE_STATUS = 'MANAGED_SERVER_STATUS'
    DRS_WLS_MANAGED_CONTROL_USECASE_START = 'MANAGED_SERVER_START'
    DRS_WLS_MANAGED_CONTROL_USECASE_STOP = 'MANAGED_SERVER_STOP'
    DRS_WLS_MANAGED_CONTROL_TIMEOUT = '1200'
    DRS_WLS_MANAGED_SERVER_TYPE = 'ManagedServer'

    #  =====  WLS NM CONTROL PARAMS
    DRS_WLS_NM_CONTROL_USECASE_STATUS = 'NM_STATUS'
    DRS_WLS_NM_CONTROL_USECASE_START = 'NM_START'
    DRS_WLS_NM_CONTROL_USECASE_STOP = 'NM_STOP'
    DRS_WLS_NM_CONTROL_TIMEOUT = '600'

    #  =====  REMOTE COMMANDS
    DRS_CMD_EXECUTE_SUDO_SU_CMD_FMT = 'sudo su - {} -c \'{} \''
    DRS_CMD_EXECUTE_SUDO_CMD_ONLY_FMT = 'sudo {}'
    DRS_CMD_EXECUTE_SCRIPT_FMT = 'cd {} && {} {}'    # cd {tmpdir} && {interpreter} {script}
    DRS_CMD_SUDO_ORACLE_EXEC_TMP_SCRIPT = \
        'sudo su - oracle -c \'export ORAENV_ASK="NO" && oraenv 2>&1 > /dev/null && sh {} \''
    DRS_CMD_SUDO_ORACLE_NOENV_EXEC_TMP_SCRIPT = 'sudo su - oracle -c \'sh {} \''
    DRS_CMD_SUDO_ORACLE_NOENV_EXEC_CMD = 'sudo su - oracle -c \'{} \''
    DRS_CMD_OPC_RM_FILE = '/bin/rm -v {}'
    DRS_CMD_OPC_BACKUP_FILE = '/bin/cp -v -a {} {}'
    DRS_CMD_OPC_MKDIR = '/bin/mkdir -v -m 700 {}'
    DRS_CMD_OPC_RMDIR = '/bin/rm -r -f -v {}'
    DRS_CMD_SUDO_CHOWN = 'sudo /bin/chown -v -R {}: {}'  # use user's default group
    DRS_CMD_SUDO_CHMOD = 'sudo /bin/chmod -v {} {}'
    DRS_CMD_ORACLE_CAT_FILE = 'cat {}'
    DRS_CMD_PERL_DOS2UNIX = 'perl - pi - e \'s/\r\n/\n/g\' {}'

    # REGULAR EXPRESSIONS
    DRS_REGEXP_DG_ROLE_DB_NAME = r'{}\s+-\s+{}'
    DRS_REGEXP_DG_CONFIG_STATUS = r'Configuration Status:\s+{}'
    DRS_REGEXP_DG_CONVERT_PHYSICAL_STANDBY = r'Database\s+\"{}\"\s+converted\s+successfully'
    DRS_REGEXP_DG_CONVERT_SNAPSHOT_STANDBY = r'Database\s+\"{}\"\s+converted\s+successfully'
    DRS_REGEXP_DG_SWITCHOVER_DB = r'Switchover\s+succeeded,\s+new\s+primary\s+is\s+\"{}\"'

    # SITE ROLES
    DRS_SITE_ROLE_PRIMARY = "PRIMARY"
    DRS_SITE_ROLE_STANDBY = "STANDBY"

    # DATABASE ROLES
    DRS_DB_ROLE_PRIMARY = "Primary database"
    DRS_DB_ROLE_PHYSICAL_STANDBY = "Physical standby database"
    DRS_DB_ROLE_SNAPSHOT_STANDBY = "Snapshot standby database"
