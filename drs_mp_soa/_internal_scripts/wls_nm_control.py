#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import time
import wls_util
import socket

__author__ = "Oracle Corp."
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """

"""

        WlsNodeManager : Class which handles Node Manager Use Cases:
        
            NM Start     : After successful start operation, status polling starts and occurs every 30 seconds
            NM Stop      : After successful stop operation, status polling starts and occurs every 30 seconds
            NM Status    : Checks status
    
    USAGE : 

        <WLST.sh> wls_nm_control.py [<USE_CASE> <TIMEOUT> <WLS_HOME> <MW_HOME> <DOMAIN_NAME> <DOMAIN_DIR> <NM_HOST> <NM_USER> <NM_PWD>]
     
    OPTIONS : 
     
        USE_CASE      : USE_CASE to be performed 
        TIMEOUT       : Timeout for status check polling 
        WLS_HOME      : Oracle WebLogic Home 
        MW_HOME       : Oracle Middleware Home 
        DOMAIN_NAME   : Oracle WebLogic Domain Name 
        DOMAIN_DIR    : Oracle WebLogic Domain Directory 
        NM_HOST       : NM Host 
        NM_USER       : NM User 
        NM_PWD        : NM Password 
    
        SUPPORTED USE CASES : 
    
            NM_START
            NM_STATUS
            NM_STOP 
            
    EXAMPLES:
    
        wlst.sh wls_nm_control.py  USE_CASE=NM_START  TIMEOUT=10000  WLS_HOME=/u01/wls_home  MW_HOME=/u01/mw_home
            DOMAIN_NAME=domain_name  DOMAIN_DIR=/u01/domain_home  NM_HOST=host  NM_USER=nmuser  NM_PWD=nmpwd
            
        <WLST.sh> wls_nm_control.py 'USE_CASE=NM_STOP' 'TIMEOUT=10000' 'WLS_HOME=/u01/wls_home' 'MW_HOME=/u01/mw_home' 'DOMAIN_NAME=domain_name'
            'DOMAIN_DIR=/u01/domain_home' 'NM_HOST=host' 'NM_USER=nmuser' 'NM_PWD=nmpwd'
        
        <WLST.sh> wls_nm_control.py 'USE_CASE=NM_STATUS' 'TIMEOUT=10000' 'WLS_HOME=/u01/wls_home' 'MW_HOME=/u01/mw_home' 'DOMAIN_NAME=domain_name'
            'DOMAIN_DIR=/u01/domain_home' 'NM_HOST=host' 'NM_USER=nmuser' 'NM_PWD=nmpwd'
        

"""


class WlsNodeManager(object):
    """
        Constructor
    """

    def __init__(self, nm_user, nm_password, nm_host, nm_port, domain_name, domain_dir, nm_connect_type, timeout, mw_home,
                 wls_home):

        if nm_user == "" or nm_password == "" or nm_host == "" or nm_port == "" or domain_name == "" or \
                        domain_dir == "" or nm_connect_type == "" or timeout == "" or mw_home == "" or wls_home == "":
            raise ValueError("One or more arguments are empty")

        # user args
        self.nm_user = nm_user
        self.nm_password = nm_password
        self.nm_host = nm_host
        self.nm_port = nm_port
        self.domain_name = domain_name
        self.domain_dir = domain_dir
        self.nm_connect_type = nm_connect_type
        self.timeout = timeout
        self.mw_home = mw_home
        self.wls_home = wls_home

        # other variables
        self.nm_start_log = "/dev/null"
        self.nm_stop_log = "/dev/null"

        self.start_time = int(time.time())
        self.sleep_time = 45
        self.start_cmd = ""
        self.stop_cmd = ""

    """
        Node Manager START
    """

    def start(self):

        print("Checking if Node Manager is already running")

        nm_status = self.status()
        if nm_status == 'NM_RUNNING':
            print("START: Node Manager state is already [%s]. Nothing to do." % nm_status)
            return nm_status

        print("Executing Node Manager Start")

        self.start_cmd = ""

        start_nm_script = '/'.join([self.domain_dir, 'bin', 'startNodeManager.sh'])

        if not os.path.exists(start_nm_script):
            w_util.exit_with_error("Could not find NM start script " + start_nm_script)
        else:
            self.start_cmd = start_nm_script

        self.nm_start_log = '/'.join([self.domain_dir, 'nodemanager', 'startnodemanager.log'])

        self.start_cmd = ' '.join([self.start_cmd, self.nm_host, self.nm_port, '>', self.nm_start_log, '2>&1 &'])

        print("Executing Start NM command : '" + self.start_cmd + "'")

        os.system(self.start_cmd)

        time.sleep(self.sleep_time)

        w_util.print_header("Start NM Log contents:")
        os.system(' '.join(['cat', self.nm_start_log]))

        return "SUCCESS : NM start triggered successfully"

    """
        Handles NM component STOP use case
    """
    def stop(self):

        print("Checking if Node Manager is already stopped")

        nm_status = self.status()
        if nm_status == 'NM_NOT_RUNNING':
            print("START: Node Manager state is already [%s]. Nothing to do." % nm_status)
            return nm_status

        print("Executing Node Manager Stop")

        self.stop_cmd = ""

        stop_nm_script = '/'.join([self.domain_dir, 'bin', 'stopNodeManager.sh'])

        if os.path.exists(stop_nm_script):
            """ For WLS 12c Stack """
            print("\nStop script '" + stop_nm_script + "' exists")

            self.nm_stop_log = '/'.join([self.domain_dir, 'nodemanager', 'stopnodemanager.log'])

            self.stop_cmd = ' '.join([stop_nm_script, '>', self.nm_stop_log, '2>&1 &'])

            print("\nExecuting Stop NM command : '" + self.stop_cmd + "'")

            os.system(self.stop_cmd)

            time.sleep(self.sleep_time)

            w_util.print_header("Stop NM Logs:")
            os.system(' '.join(['cat', self.nm_stop_log]))

            return "SUCCESS : NM stop triggered successfully"
        else:
            w_util.exit_with_error("Could not find NM stop script " + stop_nm_script)

    """
        Handles NM component STATUS use case
    """
    def status(self):

        print("Executing Node Manager Status")

        nm_connected = False

        print("Invoking: nmConnect(%s, ********, %s, %s, %s, %s, %s)" %
              (self.nm_user,  self.nm_host, self.nm_port, self.domain_name, self.domain_dir, self.nm_connect_type))
        try:
            nmConnect(self.nm_user, self.nm_password, self.nm_host, self.nm_port, self.domain_name, self.domain_dir,
                      self.nm_connect_type)
            nmVersion()
            nm_connected = True
        except:
            w_util.log_error("WARNING: Could not connect to the Node Manager")

        if nm_connected is True:
            try:
                nmDisconnect()
                print("Disconnected from Node Manager")
            except:
                w_util.log_error("WARNING: Could not disconnect from Node Manager")

        if nm_connected is True:
            return "NM_RUNNING"
        else:
            return "NM_NOT_RUNNING"

    """
        Polls status every 30 seconds until it times out after given timeout value
    """

    def poll_status(self, status):
        return w_util.poll(30, self.timeout, self.start_time, self, self.status, status, "NM")

    """
        Checks if NM is up and running
    """

    def is_nm_running(self):
        return self.status()


"""
    NOTE: This python/jython script is passed to WLST interpreter
"""


def main():

    if len(sys.argv) != 12:
        print("ERROR: Argument list is wrong.  Here are the arguments received:")
        count = 1
        for arg in sys.argv:
            print("Arg " + str(count) + ": " + arg)
            count += 1

        w_util.exit_with_error("ERROR: Number of arguments expected = 11\.  Arguments received = " + str(len(sys.argv) - 1))

    use_case = w_util.extract_params_by_name(sys.argv[1])
    timeout = w_util.extract_params_by_name(sys.argv[2])
    wls_home = w_util.extract_params_by_name(sys.argv[3])
    mw_home = w_util.extract_params_by_name(sys.argv[4])
    domain_name = w_util.extract_params_by_name(sys.argv[5])
    domain_dir = w_util.extract_params_by_name(sys.argv[6])
    nm_host = w_util.extract_params_by_name(sys.argv[7])
    nm_port = w_util.extract_params_by_name(sys.argv[8])
    nm_connect_type = w_util.extract_params_by_name(sys.argv[9])
    nm_user = w_util.extract_params_by_name(sys.argv[10])
    nm_password = w_util.extract_params_by_name(sys.argv[11])

    """
    nm_password = None
    password_string = sys.stdin.readlines()
    passwords_list = password_string[0].split()
    num_extracted_passwords = len(passwords_list)

    if num_extracted_passwords == 1:
        nm_password = passwords_list[0]
    else:
        w_util.exit_with_error("ERROR: Incorrect number of passwords [{}] passed " + str(num_extracted_passwords))
    """

    host_name = socket.gethostname()

    w_util.print_header("Node Manager Control Inputs on host [%s]:" % host_name)

    print("UseCase : '" + use_case + "'")
    print("Timeout (secs) : '" + timeout + "'")
    print("WLS Home : '" + wls_home + "'")
    print("MW Home : '" + mw_home + "'")
    print("Domain Name : '" + domain_name + "'")
    print("Domain Dir : '" + domain_dir + "'")
    print("NM Host : '" + nm_host + "'")
    print("NM Port : '" + nm_port + "'")
    print("NM Connect Type : '" + nm_connect_type + "'")
    print("NM User : '" + nm_user + "'")
    print("NM Password : ********'")

    w_util.print_dotted_line("-")

    nm = WlsNodeManager(nm_user=nm_user, nm_password=nm_password, nm_host=nm_host, nm_port=nm_port,
                        domain_name=domain_name, domain_dir=domain_dir, nm_connect_type=nm_connect_type,
                        timeout=timeout, mw_home=mw_home, wls_home=wls_home)

    if use_case == "NM_STATUS":

        status = nm.status()
        print("\nNODE MANAGER STATUS = " + status)

        if status == 'NM_RUNNING' or status == 'NM_NOT_RUNNING':
            w_util.exit(0)
        else:
            w_util.exit(1)

    elif use_case == "NM_START":

        status = nm.start()
        print("\nNODE MANAGER STATUS = " + status)

        if status != "NM_RUNNING":
            status = nm.poll_status('NM_RUNNING')

            if status == 'SUCCESS':
                w_util.exit(0)
            else:
                w_util.exit(1)
        else:
            w_util.exit(0)

    elif use_case == "NM_STOP":

        status = nm.stop()
        print("\nNODE MANAGER STATUS = " + status)

        if status != "NM_NOT_RUNNING":
            status = nm.poll_status('NM_NOT_RUNNING')

            if status == 'SUCCESS':
                w_util.exit(0)
            else:
                w_util.exit(1)
        else:
            w_util.exit(0)

    else:
        w_util.exit_with_error("Use Case '" + use_case + "' not supported")

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
    raise Exception("Cowardly and shameful... trying to import and use wls_nm_control.py module improperly!!!")

