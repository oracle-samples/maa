# -*- coding: utf-8 -*-
"""

Configuration values.

"""

__author__ = "Oracle Corp."
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """


# ====================================================================================================================
# Configuration
# ====================================================================================================================

# noinspection PyPep8Naming
class DRS_CONFIG:
    # General
    class GENERAL:
        ssh_user_name = None
        ssh_key_file = None
        ora_user_name = None
        dataguard_use_private_ip = None
        uri_to_check = None
        dr_method = None
        database_is_rac = None

    # Database - Primary
    # noinspection PyPep8Naming
    class DB_PRIM:
        host_ip = None
        host_fqdn = None
        local_ip = None
        rac_scan_ip = None
        os_version = None
        db_hostname = None
        db_host_domain = None
        db_port = None
        sysdba_user_name = None
        sysdba_password = None
        db_name = None
        db_unique_name = None
        pdb_name = None

    # Database - Standby
    # noinspection PyPep8Naming
    class DB_STBY:
        host_ip = None
        host_fqdn = None
        local_ip = None
        os_version = None
        db_hostname = None
        db_host_domain = None
        db_port = None
        sysdba_user_name = None
        sysdba_password = None
        db_name = None
        db_unique_name = None
        pdb_name = None

    # WLS - Primary
    # noinspection PyPep8Naming
    class WLS_PRIM:
        domain_name = None
        domain_home = None
        cluster_size = None
        wls_home = None
        wl_home = None
        mw_home = None
        wlsadm_user_name = None
        wlsadm_password = None
        wlsadm_host_ip = None
        wlsadm_hostname = None
        wlsadm_host_domain = None
        wlsadm_server_name = None
        wlsadm_listen_port = None
        wlsadm_nm_hostname = None
        wlsadm_nm_port = None
        wlsadm_nm_type = None
        managed_server_names = list()
        managed_server_hosts = list()
        node_manager_host_ips = list()
        cluster_node_fqdns = list()
        cluster_node_local_ips = list()
        cluster_node_public_ips = list()
        cluster_node_os_versions = list()
        front_end_ip = None
        # v13
        cluster_frontend_host = None

    # WLS - Standby
    # noinspection PyPep8Naming
    class WLS_STBY:
        domain_name = None
        domain_home = None
        cluster_size = None
        wls_home = None
        wl_home = None
        mw_home = None
        wlsadm_user_name = None
        wlsadm_password = None
        wlsadm_host_ip = None
        wlsadm_hostname = None
        wlsadm_host_domain = None
        wlsadm_server_name = None
        wlsadm_listen_port = None
        wlsadm_nm_hostname = None
        wlsadm_nm_port = None
        wlsadm_nm_type = None
        managed_server_names = list()
        managed_server_hosts = list()
        node_manager_host_ips = list()
        cluster_node_fqdns = list()
        cluster_node_local_ips = list()
        cluster_node_public_ips = list()
        cluster_node_os_versions = list()
        front_end_ip = None
        # v13
        cluster_frontend_host = None

