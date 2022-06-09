#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import time
import commands
from time import sleep


__author__ = "Oracle Corp."
__version__ = '18.0'
__copyright__ = """ Copyright (c) 2022 Oracle and/or its affiliates. Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ """


"""
    Miscellaneous w_util classes and functions
"""


class WlsUtil(object):
    """
        Extracts parameter passed to jython/python script
    """

    def extract_wls_cmd_line_params(self):

        use_case = self.extract_params_by_name(sys.argv[2])
        timeout = self.extract_params_by_name(sys.argv[3])
        mw_home = self.extract_params_by_name(sys.argv[4])
        domain_name = self.extract_params_by_name(sys.argv[5])
        domain_dir = self.extract_params_by_name(sys.argv[6])
        server_name = self.extract_params_by_name(sys.argv[7])
        server_type = self.extract_params_by_name(sys.argv[8])
        admin_host = self.extract_params_by_name(sys.argv[9])
        admin_port = self.extract_params_by_name(sys.argv[10])
        nm_host = self.extract_params_by_name(sys.argv[11])
        nm_port = self.extract_params_by_name(sys.argv[12])
        nm_type = self.extract_params_by_name(sys.argv[13])
        wls_user = self.extract_params_by_name(sys.argv[14])
        nm_user = self.extract_params_by_name(sys.argv[15])

        wls_password = None
        nm_password = None

        password_string = sys.stdin.readlines()
        passwords_list = password_string[0].split()
        num_passwords = len(passwords_list)

        if num_passwords == 1:
            self.exit_with_error("WLS or NM password not found")
        if num_passwords == 2:
            wls_password = passwords_list[0]
            nm_password = passwords_list[1]
        else:
            self.exit_with_error(
                "ERROR: Incorrect number of WLS & NM passwords found. Total num passwords found = " + str(
                    num_passwords))

        self.print_header("WebLogic Control Inputs :")

        print("UseCase : '" + use_case + "'")
        print("Timeout (in seconds) : '" + timeout + "'")
        print("MW Home : '" + mw_home + "'")
        print("Domain Name : '" + domain_name + "'")
        print("Domain Dir : '" + domain_dir + "'")
        print("Server Name : '" + server_name + "'")
        print("Server Type : '" + server_type + "'")
        print("Admin Host : '" + admin_host + "'")
        print("Admin Port : '" + admin_port + "'")
        print("NM Host : '" + nm_host + "'")
        print("NM Port : '" + nm_port + "'")
        print("NM Type : '" + nm_type + "'")
        print("WLS User : '" + wls_user + "'")
        print("NM User : '" + nm_user + "'")

        self.print_dotted_line("-")

        return use_case, timeout, mw_home, domain_name, domain_dir, server_name, server_type, admin_host, admin_port, \
            nm_host, nm_port, nm_type, wls_user, wls_password, nm_user, nm_password

    """ 
        Polls status. This method calls given API every interval seconds. It times out after given timeout occurs
    """

    def poll(self, interval, timeout, start_time, obj, status_method, expected, server_name):
        print("")
        print("=" * 110)
        print(str(server_name) + " server status polling will occur every [" + str(interval) + "] seconds. Looking for status: " + str(expected))
        print("=" * 110)
        print("")
        elapsed_time = 0
        counter = 0
        time_left = 0
        poll_timeout = 0
        default_timeout = 600
        final_status = ""

        if timeout:
            if not start_time:
                start_time = int(time.time())
            poll_timeout = int(max(int(timeout) - (time.time() - int(start_time)), 0))
        else:
            poll_timeout = int(default_timeout)

        time_left = poll_timeout

        while True:
            counter += 1
            elapsed_time += interval

            print("-" * 110)
            print("Polling attempt : '" + str(counter) + "'  |  Max Timeout : '" + str(
                poll_timeout) + "' second(s)  |  Timeout will occur after : '" + str(time_left) + "' second(s)")

            print("-" * 110)
            print("")

            time_left = max(poll_timeout - elapsed_time, 0)

            status = status_method()

            print("STATUS : %s" % status)

            if status == expected:
                print("")
                print("STATUS >>> SUCCESS : '" + server_name + "' is in '" + status + "' state")
                print("")
                final_status = "SUCCESS"
                break
            elif status == "ERROR_WHILE_CONNECTING_TO_NM":
                print("")
                print("STATUS >>> ERROR : NM Connect failed")
                print("")
                final_status = "FAILURE"
                break

            if elapsed_time >= poll_timeout:
                print("")
                print("-" * 110)
                print("STATUS >>> ERROR : Timeout occurred after %s seconds" % poll_timeout)
                print("-" * 110)
                print("")
                final_status = "FAILURE"
                break

            print("")
            print("Sleeping for %s seconds before retrying" % interval)
            sys.stdout.flush()

            sleep(interval)

	print("poll: Returning final status: %s" % final_status)
        return final_status

    """
        Command execution wrapper
    def getstatusoutput(self, cmd):
        p = Popen(cmd, stdout=PIPE)
        out, _ = p.communicate()
        return p.returncode, out
    """

    """
        Executes given command
    """

    def execute_cmd(self, cmd):
        print("Command to be executed : " + cmd)
        ret, out = commands.getstatusoutput(cmd)
        print("Command exit code : ", ret)
        print("Command output : ", out)
        sys.stdout.flush()

        if ret != 0:
            return False
        else:
            return True

    """ 
        Splits given string and returns 2nd token which is actually param value
    """

    def extract_params_by_name(self, value):
        return value.split('=')[1]
    """ 
        Prints line, 110 given characters
    """

    def print_dotted_line(self, seperator):
        print('')
        print(seperator * 110)
        print('')
        sys.stdout.flush()

    """ 
        Prints Header
    """

    def print_header(self, header):
        print('')
        print('-' * 110)
        print(header)
        print('-' * 110)
        print('')
        sys.stdout.flush()

    """ 
        Exist with given status code
    """

    def exit(self, status_code):
        sys.exit(status_code)

    """ 
        Prints status and exist with error code '1'
    """

    def exit_with_error(self, msg):
        print("STATUS >>> ERROR : " + msg)
        sys.exit(1)

    def log_error(self, msg):
        print("Unexpected error: ", sys.exc_info()[0], sys.exc_info()[1])
        print(msg)

#
# NOTE: For the ancient python version used by wlst, we need to check for "main", not "__main__"
#
if __name__ == "main" or __name__ == "__main__":
    raise Exception("Cowardly and shameful... trying to execute WlsUtil module directly!!!")
