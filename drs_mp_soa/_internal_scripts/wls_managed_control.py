#!/usr/bin/python
# -*- coding: utf-8 -*-


import sys
from time import sleep
import wls_util
import socket

__author__ = "Oracle Corp."
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """


"""

        WlsManagedServer : Class which handles Managed Server use cases
        
            Managed Server Start    : After successful start operation, status polling starts and occurs every 30 seconds
            Managed Server Stop     : After successful stop operation, status polling starts and occurs every 30 seconds
            Managed Server Status   : Checks status
    
    USAGE : 

         <WLST.sh> wls_managed_server.py [<USE_CASE> <TIMEOUT> <WLS_HOME> <MW_HOME> <DOMAIN_NAME> <DOMAIN_DIR>
            <SERVER_NAME> <SERVER_TYPE> <ADMIN_HOST> <ADMIN_PORT> <NM_HOST> <WLS_USER> <WLS_PWD> <NM_USER> <NM_PWD>]
  
    OPTIONS : 
  
        USE_CASE      : USE_CASE to be performed
        TIMEOUT       : Timeout for status check polling 
        WLS_HOME      : Oracle WebLogic Home 
        MW_HOME       : Oracle Middleware Home 
        DOMAIN_NAME   : Oracle WebLogic Domain Name 
        DOMAIN_DIR    : Oracle WebLogic Domain Directory 
        SERVER_NAME   : Server Name 
        SERVER_TYPE   : Server Type 
        ADMIN_HOST    : Admin Server Host 
        ADMIN_PORT    : Admin Server Port 
        NM_HOST       : Node Manager Host 
        WLS_USER      : Oracle WebLogic User 
        WLS_PWD       : Oracle WebLogic Password 
        NM_USER       : Node Manager User 
        NM_PWD        : Node Manager Password 
 

        SUPPORTED USE CASES : 
        
              MANAGED_SERVER_START
              MANAGED_SERVER_STATUS
              MANAGED_SERVER_STOP 

    EXAMPLES:
    
        <WLST.sh> wls_managed_control.py 'COMPONENT=MANAGED_SERVER' 'USE_CASE=MANAGED_SERVER_START' 'TIMEOUT=10000' 'WLS_HOME=/u01/wls_home' 'MW_HOME=/u01/mw_home'
            'DOMAIN_NAME=domain_name' 'DOMAIN_DIR=/u01/domain_home' 'SERVER_NAME=WLS_WSM1' 'SERVER_TYPE=ManagedServer' 'ADMIN_HOST=host' 
            'ADMIN_HOST=7001' 'NM_HOST=host' 'WLS_USER=wlsuser' 'WLS_PWD=wlspwd' 'NM_USER=nmuser' 'NM_PWD=nmpwd'
            
        <WLST.sh> wls_managed_control.py 'COMPONENT=MANAGED_SERVER' 'USE_CASE=MANAGED_SERVER_STOP' 'TIMEOUT=10000' 'WLS_HOME=/u01/wls_home' 'MW_HOME=/u01/mw_home'
            'DOMAIN_NAME=domain_name' 'DOMAIN_DIR=/u01/domain_home' 'SERVER_NAME=WLS_WSM1' 'SERVER_TYPE=ManagedServer' 'ADMIN_HOST=host' 
            'ADMIN_HOST=7001' 'NM_HOST=host' 'WLS_USER=wlsuser' 'WLS_PWD=wlspwd' 'NM_USER=nmuser' 'NM_PWD=nmpwd'
        
        <WLST.sh> wls_managed_control.py 'COMPONENT=MANAGED_SERVER' 'USE_CASE=MANAGED_SERVER_STATUS' 'TIMEOUT=10000' 'WLS_HOME=/u01/wls_home' 'MW_HOME=/u01/mw_home'
            'DOMAIN_NAME=domain_name' 'DOMAIN_DIR=/u01/domain_home' 'SERVER_NAME=WLS_WSM1' 'SERVER_TYPE=ManagedServer' 'ADMIN_HOST=host' 
            'ADMIN_HOST=7001' 'NM_HOST=host' 'WLS_USER=wlsuser' 'WLS_PWD=wlspwd' 'NM_USER=nmuser' 'NM_PWD=nmpwd'

"""


class WlsManagedServer(object):
    """
        Constructor
    """

    def __init__(self, wls_user, wls_password, admin_host, admin_port, server_name, server_type, domain_name,
                 domain_dir, nm_user, nm_password, nm_host, nm_port, nm_connect_type, timeout):

        if wls_user == "" or wls_password == "" or admin_host == "" or admin_port == "" or server_name == "" or \
                        server_type == "" or domain_name == "" or domain_dir == "" or nm_user == "" or \
                        nm_password == "" or nm_host == "" or nm_port == "" or nm_connect_type == "" or timeout == "":
            raise ValueError("One or more arguments are empty")

        # user args
        self.wls_user = wls_user
        self.wls_password = wls_password
        self.admin_host = admin_host
        self.admin_port = admin_port
        self.server_name = server_name
        self.server_type = server_type
        self.domain_name = domain_name
        self.domain_dir = domain_dir
        self.nm_user = nm_user
        self.nm_password = nm_password
        self.nm_host = nm_host
        self.nm_port = nm_port
        self.nm_connect_type = nm_connect_type
        self.timeout = timeout

        # other variables
        self.start_time = int(time.time())
        self.wlst_connected = self.failed = self.server_started = self.nm_connected = False
        self.server_stopped = self.server_status = self.is_nm_running = False

    def status_old(self):
        print("Connecting to Node Manager to check state of Managed Server [%s] ..." % self.server_name)

        nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                  self.nm_connect_type)
        server_state = nmServerStatus(self.server_name)
        print("Disconnecting from Node Manager ...")
        nmDisconnect()
        return server_state

    """
    def get_current_state(self):
        print("Connecting to Admin Server to check state of Managed Server [%s] ..." % self.server_name)
        connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
        domainRuntime()
        server_bean = cmo.lookupServerLifeCycleRuntime(self.server_name)
        server_state = server_bean.getState()
        print("Current state of Managed Server [%s] is [%s]" % (self.server_name, server_state))
        return server_state
    """

    def status_using_admin_server(self, poll_timeout=None, expected_state=None):
        print("Connecting to Admin Server to check state of Managed Server [%s] ..." % self.server_name)
        connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
        domainRuntime()
        server_bean = cmo.lookupServerLifeCycleRuntime(self.server_name)
        server_state = server_bean.getState()
        print("STATUS: Current state of Managed Server [%s] is [%s]\n" % (self.server_name, server_state))

        if poll_timeout is not None and server_state != expected_state:
            total_time_left = int(poll_timeout)
            sleep_interval = int(30)  # seconds
            while True:
                print("----------------------------------------------------------------------------------------------")
                print("STATUS: Polling for state change: Current state = [%s]. Polling time left = [%s] seconds" % \
                      (server_state, total_time_left))
                server_state = server_bean.getState()
                if server_state == expected_state:
                    print("\n    ***** Terminal state changed detected.  Final State = [%s] *****\n" % server_state)
                    break
                else:
                    print("STATUS: Sleeping for %s seconds before rechecking state" % sleep_interval)
                    sleep(sleep_interval)
                    total_time_left -= sleep_interval
                if total_time_left > 0:
                    continue
                else:
                    raise Exception("STATUS: Timed out waiting for server state change")
            print("STATUS: Returning state [%s] for Managed Server [%s]" % (server_state, self.server_name))
            disconnect()
            return server_state
        else:
            print("STATUS: Returning state [%s] for Managed Server [%s]" % (server_state, self.server_name))
            disconnect()
            return server_state

    def status_using_node_manager(self):
        self.nm_connected = self.server_status = ""

        try:
            nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                      self.nm_connect_type)
            self.nm_connected = 1
        except:
            w_util.log_error("WARNING: Could not connect to the Node Manager")
            return "ERROR_WHILE_CONNECTING_TO_NM"

        if self.nm_connected == 1:
            try:
                self.server_status = nmServerStatus(self.server_name)
            except:
                w_util.log_error("WARNING: nmServerStatus(" + self.server_name + ") failed")

        if self.nm_connected == 1:
            try:
                nmDisconnect()
                print("Disconnected from Node Manager")
            except:
                w_util.log_error("WARNING: Could not disconnect from Node Manager")

        if self.server_status not in ['RUNNING', 'ADMIN']:
            return self.server_status
        else:
            return "RUNNING"


    def start(self):

        server_state = None
        as_connect_failed = False
        nm_connected = False
        server_started = False

        try:
            print("Connecting to Admin Server to get status of Managed Server [%s] ..." % self.server_name)
            server_state = self.status_using_admin_server()
        except Exception:
            print("Caught exception trying to connect to Admin Server to get MS status")
            as_connect_failed = True

        if as_connect_failed:
            print("Continuing undaunted... Trying to connect to Node Manger to get Managed Server status")
            server_state = self.status_using_node_manager()

        if server_state == 'RUNNING' or server_state == 'STARTING':
            print("START: Managed Server state is already [%s]. Nothing to do." % server_state)
            return "RUNNING"

        as_connect_failed = False
        server_started = False

        try:
            print("Connecting to Admin Server to start Managed Server [%s] ..." % self.server_name)
            connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
            serverConfig()
            cd("/Servers/" + self.server_name)
            print("START: Starting Managed Server [%s] ..." % self.server_name)
            start(self.server_name, 'Server', block='false')
            print("START: Disconnecting from Admin Server ...")
            disconnect()
            server_started = True
            return "STARTING"
        except Exception:
            print("Caught exception trying to connect to Admin Server to start MS")
            as_connect_failed = True

        if as_connect_failed:
            print("Continuing undaunted... Trying to connect to Node Manger to start Managed Server ")
            nm_connected = False
            try:
                nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                          self.nm_connect_type)
                nm_connected = True
            except:
                print("ERROR: Could not connect to the Node Manager")
                return "ERROR_WHILE_CONNECTING_TO_NM"

            if nm_connected:
                try:
                    nmStart(self.server_name)
                    server_started = True
                except:
                    print("ERROR: nmStart(" + self.server_name + ") failed")

            if nm_connected:
                try:
                    nmDisconnect()
                    print("Disconnected from Node Manager")
                except:
                    print("ERROR: Could not disconnect from Node Manager")

        if server_started:
            print(self.server_name + " [" + self.server_type + "] START triggered successfully")
            return "STOPPING"

        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] start failed")

    def stop(self):
        server_state = None
        as_connect_failed = False
        nm_connected = False
        server_stopped = False

        try:
            print("Connecting to Admin Server to get status of Managed Server [%s] ..." % self.server_name)
            server_state = self.status_using_admin_server()
        except Exception:
            print("Caught exception trying to connect to Admin Server to get MS status")
            as_connect_failed = True

        if as_connect_failed:
            print("Continuing undaunted... Trying to connect to Node Manger to get Managed Server status")
            server_state = self.status_using_node_manager()

        if server_state == 'SHUTDOWN' or server_state == 'SUSPENDING' or server_state == 'SHUTTING_DOWN':
            print("STOP: Managed Server state is already [%s]. Nothing to do." % server_state)
            return "SHUTDOWN"

        as_connect_failed = False
        server_stopped = False

        try:
            print("Connecting to Admin Server to stop Managed Server [%s] ..." % self.server_name)
            connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
            print("STOP: Executing nmGenBootStartupProps(%s)" % self.server_name)
            nmGenBootStartupProps(self.server_name)
            serverConfig()
            cd("/Servers/" + self.server_name)
            print("STOP: Stopping Managed Server [%s] ..." % self.server_name)
            shutdown(self.server_name, 'Server', block='false', timeOut=600, ignoreSessions='true')
            print("STOP: Disconnecting from Admin Server ...")
            disconnect()
            server_stopped = True
        except Exception:
            print("Caught exception trying to connect to Admin Server to stop MS")
            as_connect_failed = True

        if as_connect_failed:
            print("Continuing undaunted... Trying to connect to Node Manger to stop Managed Server ")
            nm_connected = False
            try:
                nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                          self.nm_connect_type)
                nm_connected = True
            except:
                print("ERROR: Could not connect to the Node Manager")
                return "ERROR_WHILE_CONNECTING_TO_NM"

            if nm_connected:
                try:
                    nmKill(self.server_name)
                    server_stopped = True
                except:
                    print("ERROR: nmKill(" + self.server_name + ") failed")

            if nm_connected:
                try:
                    nmDisconnect()
                    print("Disconnected from Node Manager")
                except:
                    print("ERROR: Could not disconnect from Node Manager")

        if server_stopped:
            print(self.server_name + " [" + self.server_type + "] SHUTDOWN triggered successfully")
            return "STOPPING"

        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] stop failed")

    def poll_status(self, status):
        status = w_util.poll(30, self.timeout, self.start_time, self, self.status_using_node_manager, status,
                             self.server_name)
        print("w_util.poll returned status: %s" % status)
        return status

    def zzz_start_old(self):
        self.wlst_connected = self.failed = self.server_started = self.nm_connected = ""

        try:
            connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
        except:
            w_util.exit_with_error("ERROR: Could not connect to the Admin Server")

        try:
            cd("/Servers/" + self.server_name)
            start(self.server_name, 'Server', block='false')
            self.server_started = 1
        except:
            w_util.exit_with_error("ERROR: '" + self.server_name + "' server failed to start")
            self.failed = 1

        if self.wlst_connected == 1:
            try:
                disconnect()
                print("Disconnected from Admin Server")
            except:
                w_util.log_error("WARNING: disconnect failed")

        if self.failed == 1:
            print("WARNING: Connecting to admin server or server start failed using WLST")
            print("Connecting NM for server start...")

            try:
                nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                          self.nm_connect_type)
                self.nm_connected = 1
            except:
                w_util.log_error("WARNING: Could not connect to the Node Manager")
                w_util.exit_with_error("NM Connect failed")

            if self.nm_connected == 1:
                try:
                    nmStart(self.server_name)
                    self.server_started = 1
                except:
                    w_util.log_error("WARNING: nmStart(" + self.server_name + ") failed")

            if self.nm_connected == 1:
                try:
                    nmDisconnect()
                    print("Disconnected from Node Manager")
                except:
                    w_util.log_error("WARNING: Could not disconnect from Node Manager")

        if self.server_started == 1:
            return self.server_name + " [" + self.server_type + "] start triggered successfully"
        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] start failed")

    def zzz_stop_old(self):
        self.wlst_connected = self.failed = self.server_stopped = self.nm_connected = ""

        try:
            connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
            self.wlst_connected = 1
        except:
            w_util.log_error("WARNING: Could not connect to the Admin Server")
            self.failed = 1

        if self.wlst_connected == 1:
            # check if managed server is already SHUTDOWN
            domainRuntime()
            server_bean = cmo.lookupServerLifeCycleRuntime(self.server_name)
            server_state = server_bean.getState()
            print("Status of Server [%s] is [%s]" % (self.server_name, server_state))
            if server_state == 'SHUTDOWN':
                print("Server is already SHUTDOWN. Nothing to do")
        else:
            if self.wlst_connected == 1:
                try:
                    print("Executing nmGenBootStartupProps(" + self.server_name + ")\n")
                    nmGenBootStartupProps(self.server_name)
                    print("\nExecution of nmGenBootStartupProps(" + self.server_name + ") completed")
                except:
                    w_util.log_error("\nWARNING: nmGenBootStartupProps(" + self.server_name +
                                     ") failed while generating the Node Manager property files, boot.properties and startup.properties")

            if self.wlst_connected == 1:
                try:
                    cd("/Servers/" + self.server_name)
                    print("\nExecuting shutdown('" + self.server_name +
                          "', 'Server', block='false', timeOut=600, ignoreSessions='true')")
                    shutdown(self.server_name, 'Server', block='false', timeOut=600, ignoreSessions='true')
                    print("\nExecution of shutdown('" + self.server_name +
                          "', 'Server', block='false', timeOut=600, ignoreSessions='true') completed")
                    self.server_stopped = 1
                except:
                    w_util.log_error("WARNING: " + self.server_name + " server failed to stop")
                    self.failed = 1

            if self.wlst_connected == 1:
                try:
                    disconnect()
                    print("Disconnected from Admin Server (WLST)")
                except:
                    w_util.log_error("WARNING: disconnect failed")

        if self.failed == 1:
            print("WARNING: Connecting to admin server or server start failed using WLST")
            print("Connecting NM for server stop...")

            try:
                nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                          self.nm_connect_type)
                self.nm_connected = 1
            except:
                w_util.log_error("WARNING: Could not connect to the Node Manager")
                w_util.exit_with_error("NM Connect failed")

            if self.nm_connected == 1:
                try:
                    nmKill(self.server_name)
                    self.server_stopped = 1
                except:
                    w_util.log_error("WARNING: nmKill(" + self.server_name + ") failed")

            if self.nm_connected == 1:
                try:
                    nmDisconnect()
                    print("Disconnected from Node Manager")
                except:
                    w_util.log_error("WARNING: Could not disconnect from Node Manager")

        if self.server_stopped == 1:
            print(self.server_name + " [" + self.server_type + "] SHUTDOWN triggered successfully")
            return "STOPPING"

        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] stop failed")


def main():
    print("Starting script [%s] ..." % sys.argv[0])
    if len(sys.argv) != 18:
        print("ERROR: Argument list is wrong.  Here are the arguments received:")
        count = 1
        for arg in sys.argv:
            print("Arg " + str(count) + ": " + arg)
            count += 1

        w_util.exit_with_error(
            "ERROR: Number of arguments expected = 17.  Arguments received = " + str(len(sys.argv) - 1))

    use_case = w_util.extract_params_by_name(sys.argv[1])
    timeout = w_util.extract_params_by_name(sys.argv[2])
    wls_home = w_util.extract_params_by_name(sys.argv[3])
    mw_home = w_util.extract_params_by_name(sys.argv[4])
    domain_name = w_util.extract_params_by_name(sys.argv[5])
    domain_dir = w_util.extract_params_by_name(sys.argv[6])
    server_name = w_util.extract_params_by_name(sys.argv[7])
    server_type = w_util.extract_params_by_name(sys.argv[8])
    admin_host = w_util.extract_params_by_name(sys.argv[9])
    admin_port = w_util.extract_params_by_name(sys.argv[10])
    nm_host = w_util.extract_params_by_name(sys.argv[11])
    nm_port = w_util.extract_params_by_name(sys.argv[12])
    nm_connect_type = w_util.extract_params_by_name(sys.argv[13])
    wls_user = w_util.extract_params_by_name(sys.argv[14])
    wls_password = w_util.extract_params_by_name(sys.argv[15])
    nm_user = w_util.extract_params_by_name(sys.argv[16])
    nm_password = w_util.extract_params_by_name(sys.argv[17])

    """
    node_manager_password = None
    password_string = sys.stdin.readlines()
    passwords_list = password_string[0].split()
    num_extracted_passwords = len(passwords_list)

    if num_extracted_passwords == 1:
        node_manager_password = passwords_list[0]
    else:
        w_util.exit_with_error("ERROR: Incorrect number of passwords [{}] passed " + str(num_extracted_passwords))
    """

    host_name = socket.gethostname()

    w_util.print_header("Managed Server Control Inputs on host [%s]:" % host_name)

    print("UseCase : '" + use_case + "'")
    print("Timeout (secs) : '" + timeout + "'")
    print("WLS Home : '" + wls_home + "'")
    print("MW Home : '" + mw_home + "'")
    print("Domain Name : '" + domain_name + "'")
    print("Domain Dir : '" + domain_dir + "'")
    print("Server Name : '" + server_name + "'")
    print("Server Type : '" + server_type + "'")
    print("Admin Host : '" + admin_host + "'")
    print("Admin Port : '" + admin_port + "'")
    print("NM Host : '" + nm_host + "'")
    print("NM Port : '" + nm_port + "'")
    print("NM Connect Type : '" + nm_connect_type + "'")
    print("WLS User : '" + wls_user + "'")
    print("WLS Password : ********'")
    print("NM User : '" + nm_user + "'")
    print("NM Password : ********'")

    w_util.print_dotted_line("-")

    managed_server = WlsManagedServer(wls_user=wls_user, wls_password=wls_password, admin_host=admin_host,
                                      admin_port=admin_port, server_name=server_name, server_type=server_type,
                                      domain_name=domain_name, domain_dir=domain_dir, nm_user=nm_user,
                                      nm_password=nm_password, nm_host=nm_host, nm_port=nm_port,
                                      nm_connect_type=nm_connect_type, timeout=timeout)

    if use_case == "MANAGED_SERVER_STATUS":

        status = managed_server.status_using_node_manager()

        print("\nMANAGED SERVER STATUS = " + status + "\n")

        if status == 'RUNNING' or status == 'SHUTDOWN':
            w_util.exit(0)
        else:
            w_util.exit(1)

    elif use_case == "MANAGED_SERVER_START":

        status = managed_server.start()

        if 'RUNNING' not in status and 'ERROR' not in status:
            poll_status = managed_server.poll_status('RUNNING')
            if poll_status != 'SUCCESS':
                raise Exception("*** ERROR: Managed server start FAILED")
            else:
                print("\nMANAGED SERVER STATUS = " + poll_status + "\n")
                w_util.exit(0)
        else:
            print("\nMANAGED SERVER STATUS = " + status + "\n")
            w_util.exit(0)

    elif use_case == "MANAGED_SERVER_STOP":

        status = managed_server.stop()

        print("Managed Server status is [%s]" % status)

        if 'SHUTDOWN' not in status and 'ERROR' not in status:
            poll_status = managed_server.poll_status('SHUTDOWN')
            if poll_status != 'SUCCESS':
                raise Exception("*** ERROR: Managed server stop FAILED")
            else:
                print("\nMANAGED SERVER STATUS = " + poll_status + "\n")
                w_util.exit(0)
        else:
            print("\nMANAGED SERVER STATUS = " + status + "\n")
            w_util.exit(0)

    else:
        w_util.exit_with_error("Use Case [%s] not supported" % use_case)

    print("")


"""
    Main entry point
"""
#
# NOTE: For the ancient python version used by wlst, we need to check for "main", not "__main__"
#
if __name__ == "main" or __name__ == "__main__":
    w_util = wls_util.WlsUtil()
    main()
else:
    raise Exception("Cowardly and shameful... trying to import and use wls_managed_control.py module improperly!!!")

