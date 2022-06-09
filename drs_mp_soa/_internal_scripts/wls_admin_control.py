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

        WlsAdminServer : Class which handles Admin Server use cases
        
            Admin Server Start      : After successful start operation, status polling starts and occurs every 30 seconds
            Admin Server Stop       : After successful stop operation, status polling starts and occurs every 30 seconds
            Admin Server Status     : Checks status
    
    USAGE : 

         <WLST.sh> wls_admin_control.py [<USE_CASE> <TIMEOUT> <WLS_HOME> <MW_HOME> <DOMAIN_NAME> <DOMAIN_DIR>
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
        
              ADMIN_SERVER_START
              ADMIN_SERVER_STATUS
              ADMIN_SERVER_STOP
            
    USAGE EXAMPLE:
        wlst.sh wls_admin_control.py USE_CASE=ADMIN_SERVER_START TIMEOUT=1200
            WLS_HOME=/u01/app/oracle/middleware/wlserver/server MW_HOME=/u01/app/oracle/middleware
            DOMAIN_NAME=soadr2oc_domain DOMAIN_DIR=/u01/data/domains/soadr2oc_domain
            SERVER_NAME=soadr2oc_adminserver SERVER_TYPE=AdminServer
            ADMIN_HOST=soadr2ociprimary-wls-1 ADMIN_PORT=7001
            NM_HOST=soadr2ociprimary-wls-1 NM_PORT=5556 NM_CONNECT_TYPE=SSL
            WLS_USER=weblogic WLS_PASSWORD=welcome1
            NM_USER=weblogic NM_PASSWORD=welcome1


"""


class WlsAdminServer(object):
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
        self.nm_connected = self.server_stopped = self.server_started = self.server_status = \
            self.is_nm_running = self.wlst_connected = self.failed = None

    def status(self, poll_timeout=None, expected_state=None):

        print("STATUS: Connecting to Node Manager using: nmConnect(%s, ********, %s, %s, %s, %s, %s)" %
              (self.nm_user,  self.nm_host, self.nm_port, self.domain_name, self.domain_dir, self.nm_connect_type))

        nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                  self.nm_connect_type)

        print("STATUS: Invoking: nmServerStatus(%s)" % self.server_name)
        server_state = nmServerStatus(self.server_name)
        print("STATUS: Current state of Admin Server [%s] is [%s]\n" % (self.server_name, server_state))

        if poll_timeout is not None and server_state != expected_state:
            total_time_left = int(poll_timeout)
            sleep_interval = int(30)  # seconds
            while True:
                print("----------------------------------------------------------------------------------------------")
                print("STATUS: Polling for state change: Current state = [%s]. Polling time left = [%s] seconds" % \
                      (server_state, total_time_left))
                server_state = nmServerStatus(self.server_name)
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
            print("STATUS: Invoking: nmDisconnect()")
            nmDisconnect()
            print("STATUS: Disconnected from Node Manager")
            print("STATUS: Returning state [%s] for Admin Server [%s]" % (server_state, self.server_name))
            return server_state
        else:
            print("STATUS: Invoking: nmDisconnect()")
            nmDisconnect()
            print("STATUS: Disconnected from Node Manager")
            print("STATUS: Returning state [%s] for Admin Server [%s]" % (server_state, self.server_name))
            return server_state

    def start(self):

        print("START: Connecting to Node Manager using: nmConnect(%s, ********, %s, %s, %s, %s, %s)" %
              (self.nm_user,  self.nm_host, self.nm_port, self.domain_name, self.domain_dir, self.nm_connect_type))

        nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                  self.nm_connect_type)

        print("START: Invoking: nmServerStatus(%s)" % self.server_name)

        server_state = nmServerStatus(self.server_name)

        print("START: Current state of Admin Server [%s] is [%s]\n" % (self.server_name, server_state))

        if server_state == 'RUNNING' or server_state == 'STARTING':
            print("START: Admin Server state is already [%s]. Nothing to do." % server_state)
            return "RUNNING"
        else:
            print("START: Initiating start of Admin Server using: nmStart(%s)" % self.server_name)
            nmStart(self.server_name)

            print("START: Disconnecting from Node Manager")
            nmDisconnect()
            print("START: Disconnected from Node Manager")
            return "STARTING"

    def stop(self):

        server_state = self.status()
        if server_state == 'SHUTDOWN' or server_state == 'SUSPENDING' or server_state == 'SHUTTING_DOWN' or server_state == 'ADMIN':
            print("STOP: Admin Server is already in state [%s]. Nothing to do." % server_state)
            return "SHUTDOWN"
        else:
            print("STOP: Connecting to Admin Server using: connect(%s, ********, 't3://' + %s + ':' + %s)" %
                  (self.wls_user, self.admin_host, self.admin_port))

            connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)

            print("STOP: Executing nmGenBootStartupProps(" + self.server_name + ")\n")
            nmGenBootStartupProps(self.server_name)
            print("\nSTOP: Execution of nmGenBootStartupProps(" + self.server_name + ") completed")

            cd("/Servers/" + self.server_name)
            print(
                "\nSTOP: Executing shutdown('" + self.server_name +
                "', 'Server', block='false', timeOut=600, ignoreSessions='true')")
            shutdown(self.server_name, 'Server', block='false', timeOut=600, ignoreSessions='true')
            print(
                "\nSTOP: Finished executing shutdown('" + self.server_name +
                "', 'Server', block='false', timeOut=600, ignoreSessions='true') completed")

            print("STOP: Disconnecting from Admin Server")
            disconnect()
            print("STOP: Disconnected from Admin Server")
            return "STOPPING"


    def zzz_old_start(self):

        self.nm_connected = False
        self.server_started = False
        server_already_running = False

        print("Checking if Admin Server is already RUNNING ...")
        print("Trying to connect to Node Manager ...")

        try:
            print("Invoking: nmConnect(%s, ********, %s, %s, %s, %s, %s)" %
                  (self.nm_user,  self.nm_host, self.nm_port, self.domain_name, self.domain_dir, self.nm_connect_type))

            nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                      self.nm_connect_type)
            self.nm_connected = True
        except:
            w_util.exit_with_error("ERROR: Could not connect to the Node Manager")

        try:
            print("Invoking: nmServerStatus(%s)" % self.server_name)
            sys.stdout.flush()

            result = nmServerStatus(self.server_name)
            if result == 'RUNNING':
                print("Admin Server is already RUNNING")
                self.server_started = True
                server_already_running = True
            elif result == 'SHUTDOWN':
                print("Admin Server is currently SHUTDOWN")
                self.server_started = False
                server_already_running = False
            else:
                w_util.exit_with_error("ERROR: Got unknown status [" + status + "] from nmServerStatus()")

        except:
            w_util.exit_with_error("ERROR: Could not get Admin Server status")

        if server_already_running is False:
            print("Initiating start of Admin Server using: nmStart(" + self.server_name + ") ...")
            try:
                print("Invoking: nmStart(%s)" % self.server_name)
                sys.stdout.flush()
                nmStart(self.server_name)
                self.server_started = True
            except:
                w_util.exit_with_error("ERROR: nmStart(" + self.server_name + ") failed")

        try:
            print("Invoking: nmDisconnect()")
            nmDisconnect()
            print("Disconnected from Node Manager")
            self.nm_connected = False
        except:
            w_util.exit_with_error("ERROR: Could not disconnect from Node Manager")

        if self.server_started is True:
            if server_already_running is True:
                print(self.server_name + " [" + self.server_type + "] is already RUNNING")
                return "RUNNING"
            else:
                print(self.server_name + " [" + self.server_type + "] START triggered successfully")
                return "STARTED"
        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] start failed")

    def zzz_old_stop(self):
        self.nm_connected = self.server_stopped = self.wlst_connected = self.failed = False
        server_already_shutdown = False

        print("Checking if Admin Server is already SHUTDOWN ...")
        print("Trying to connect to Node Manager ...")

        try:
            print("Invoking: nmConnect(%s, ********, %s, %s, %s, %s, %s)" %
                  (self.nm_user,  self.nm_host, self.nm_port, self.domain_name, self.domain_dir, self.nm_connect_type))

            nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                      self.nm_connect_type)
            self.nm_connected = True
        except:
            w_util.exit_with_error("ERROR: Could not connect to the Node Manager")

        try:
            print("Invoking: nmServerStatus(%s)" % self.server_name)
            result = nmServerStatus(self.server_name)
            if result == 'SHUTDOWN':
                print("Admin Server is already SHUTDOWN")
                self.server_stopped = True
                server_already_shutdown = True
            elif result == 'RUNNING':
                print("Admin Server is currently RUNNING")
                self.server_stopped = False
                server_already_shutdown = False
            else:
                w_util.exit_with_error("ERROR: Got unknown status [" + status + "] from nmServerStatus()")
        except:
            w_util.exit_with_error("ERROR: Could not get Admin Server status")

        try:
            print("Invoking: nmDisconnect()")
            nmDisconnect()
            print("Disconnected from Node Manager")
            self.nm_connected = False
        except:
            w_util.exit_with_error("ERROR: Could not disconnect from Node Manager")

        if server_already_shutdown is False:

            print("Trying to connect to Admin Server ...")

            try:
                print("Invoking: connect(%s, ********, 't3://' + %s + ':' + %s)" %
                      (self.wls_user, self.admin_host, self.admin_port))

                connect(self.wls_user, self.wls_password, 't3://' + self.admin_host + ':' + self.admin_port)
            except:
                w_util.exit_with_error("WARNING: Could not connect to the Admin Server")

            try:
                print("Executing nmGenBootStartupProps(" + self.server_name + ")\n")
                nmGenBootStartupProps(self.server_name)
                print("\nExecution of nmGenBootStartupProps(" + self.server_name + ") completed")
            except:
                w_util.exit_with_error(
                    "\nERROR: nmGenBootStartupProps(" + self.server_name +
                    ") failed while generating the Node Manager property files, boot.properties and startup.properties")

            try:
                cd("/Servers/" + self.server_name)
                print(
                    "\nExecuting shutdown('" + self.server_name +
                    "', 'Server', block='false', timeOut=600, ignoreSessions='true')")
                shutdown(self.server_name, 'Server', block='false', timeOut=600, ignoreSessions='true')
                print(
                    "\nExecution of shutdown('" + self.server_name +
                    "', 'Server', block='false', timeOut=600, ignoreSessions='true') completed")
                self.server_stopped = True
            except:
                w_util.exit_with_error("ERROR: " + self.server_name + " Admin server failed to shutdown")
                self.failed = True

            try:
                disconnect()
                print("Disconnected from Admin Server (WLST)")
            except:
                w_util.exit_with_error("WARNING: Disconnect from Admin Server failed")

            if self.failed is True:
                print("WARNING: Connecting to admin server or server start failed using WLST")
                print("Connecting to NM to attempt Admin server stop...")

        if self.server_stopped is True:
            return self.server_name + " [" + self.server_type + "] stop triggered successfully"
        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] stop failed")

        if self.server_stopped is True:
            if server_already_shutdown is True:
                print(self.server_name + " [" + self.server_type + "] is already SHUTDOWN")
                return "SHUTDOWN"
            else:
                print(self.server_name + " [" + self.server_type + "] SHUTDOWN triggered successfully")
                return "STOPPING"
        else:
            w_util.exit_with_error(self.server_name + " [" + self.server_type + "] stop failed")

    def zzz_old_status(self):
        self.nm_connected = self.server_status = ""

        print("Trying to connect to Node Manager ...")

        try:
            print("Invoking: nmConnect(%s, ********, %s, %s, %s, %s, %s)" %
                  (self.nm_user,  self.nm_host, self.nm_port, self.domain_name, self.domain_dir, self.nm_connect_type))

            nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                      self.nm_connect_type)
            self.nm_connected = 1
        except:
            w_util.log_error("WARNING: Could not connect to the Node Manager")
            return "ERROR_WHILE_CONNECTING_TO_NM"

        print("Trying to get Admin Server Status ...")

        if self.nm_connected == 1:
            try:
                print("Invoking: nmServerStatus(%s)" % self.server_name)
                self.server_status = nmServerStatus(self.server_name)
            except:
                w_util.log_error("WARNING: nmServerStatus(" + self.server_name + ") failed")

        print("Successfully obtained Admin Server Status.")

        if self.nm_connected == 1:
            try:
                print("Invoking: nmDisconnect()")
                nmDisconnect()
                print("Disconnected from Node Manager")
            except:
                w_util.log_error("WARNING: Could not disconnect from Node Manager")

        if self.server_status not in ['RUNNING', 'ADMIN']:
            return self.server_status
        else:
            return "RUNNING"

    def zzz_poll_status(self, status):
        # print("Starting poll using params: %d, %d, %s, %s, %s)" %
        #      (30, self.timeout, self.start_time, status, self.server_name))
        return w_util.poll(30, self.timeout, self.start_time, self, status, self.server_name)

    def zzz_check_if_nm_running(self):
        self.is_nm_running = ""

        try:
            nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                      self.nm_connect_type)
            nmVersion()
            self.is_nm_running = 1
        except:
            w_util.log_error("WARNING: Could not connect to the Node Manager")

        if self.is_nm_running == 1:
            try:
                nmDisconnect()
                print("Disconnected from Node Manager")
            except:
                w_util.log_error("WARNING: Could not disconnect from Node Manager")

        if self.is_nm_running == 1:
            return "NM_RUNNING"
        else:
            return "NM_NOT_RUNNING"


def main():

    if len(sys.argv) != 18:
        print("ERROR: Argument list is wrong.  Here are the arguments received:")
        count = 1
        for arg in sys.argv:
            print("Arg " + str(count) + ": " + arg)
            count += 1

        w_util.exit_with_error("ERROR: Number of arguments expected = 17.  Arguments received = " + str(len(sys.argv) - 1))

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

    w_util.print_header("Admin Server Control Inputs on host [%s]:" % host_name)

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
    sys.stdout.flush()

    admin_server = WlsAdminServer(wls_user=wls_user, wls_password=wls_password, admin_host=admin_host,
                                  admin_port=admin_port, server_name=server_name, server_type=server_type,
                                  domain_name=domain_name, domain_dir=domain_dir, nm_user=nm_user,
                                  nm_password=nm_password, nm_host=nm_host, nm_port=nm_port,
                                  nm_connect_type=nm_connect_type, timeout=timeout)

    """
    if use_case == "NM_STATUS":

        nm_status = admin_server.check_if_nm_running()
        print("\nNM STATUS : " + nm_status)

        if nm_status == 'NM_RUNNING':
            w_util.exit(0)
        else:
            w_util.exit(1)
    """

    if use_case == "ADMIN_SERVER_STATUS":

        status = admin_server.status()

        print("\nADMIN SERVER STATUS = " + status + "\n")

        if status == 'RUNNING' or status == 'SHUTDOWN':
            w_util.exit(0)
        else:
            w_util.exit(1)

    elif use_case == "ADMIN_SERVER_START":

        status = admin_server.start()

        if 'RUNNING' not in status and 'ERROR' not in status:
            poll_status = admin_server.status(timeout, 'RUNNING')
            if poll_status != 'RUNNING':
                raise Exception("*** ERROR: Admin server start FAILED")
            else:
                print("\nADMIN SERVER STATUS = " + poll_status + "\n")
                w_util.exit(0)
        else:
            print("\nADMIN SERVER STATUS = " + status + "\n")
            w_util.exit(0)

    elif use_case == "ADMIN_SERVER_STOP":

        status = admin_server.stop()

        if 'SHUTDOWN' not in status and 'ERROR' not in status:
            poll_status = admin_server.status(timeout, 'SHUTDOWN')
            if poll_status != 'SHUTDOWN':
                raise Exception("*** ERROR: Admin server stop FAILED")
            else:
                print("\nADMIN SERVER STATUS = " + poll_status + "\n")
                w_util.exit(0)
        else:
            print("\nADMIN SERVER STATUS = " + status + "\n")
            w_util.exit(0)

    else:
        w_util.exit_with_error("Use Case [%s] not supported" % use_case)


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
    raise Exception("Cowardly and shameful... trying to import and use wls_admin_control.py module improperly!!!")
