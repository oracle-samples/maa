"""
Copyright (c) 2023 Oracle and/or its affiliates. 
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
"""
import os
import sys
import socket
from xml.dom import minidom
sys.path.append("/opt/scripts/")
import databag

adminServerName = databag.getWlsAdminServerName()
managedServerName = databag.getWlsMSServerName()+str(databag.getHostIndex())
wls_admin_port=databag.getWlsAdminPort()
admin_host_name= databag.getWlsAdminHost()
adminURL = 't3://' + admin_host_name + ':' + str(wls_admin_port)

serverType=sys.argv[1]
wlsadminconfigfile=sys.argv[2]
wlsadminkeyfile=sys.argv[3]


if serverType == "AdminServer":
  try:
    connect(userConfigFile=wlsadminconfigfile, userKeyFile=wlsadminkeyfile, url=adminURL)
    shutdown(adminServerName)
    disconnect()
  except Exception, e:
    dumpStack()
    disconnect()
    raise Exception('Failed to stop admin server')

elif serverType == "ManagedServer":
  try:
    connect(userConfigFile=wlsadminconfigfile, userKeyFile=wlsadminkeyfile, url=adminURL)
    shutdown(managedServerName)
    disconnect()
  except Exception, e:
    dumpStack()
    disconnect()
    raise Exception('Failed to stop managed server')

