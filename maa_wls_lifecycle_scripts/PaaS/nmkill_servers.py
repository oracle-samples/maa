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

domainDir = databag.getDomainDir()
domainName = databag.getWlsDomainName()
domainHome = domainDir + "/" + domainName
adminServerName = databag.getWlsAdminServerName()
managedServerName = databag.getWlsMSServerName()+str(databag.getHostIndex())
hostName=socket.getfqdn()
nmPort=int(databag.getWlsNmPort())
configPath = domainHome + "/config/config.xml"

wls_admin_port=databag.getWlsAdminPort()
admin_host_name= databag.getWlsAdminHost()
adminURL = 't3://' + admin_host_name + ':' + str(wls_admin_port)
nmtype = 'ssl'
serverType=sys.argv[1]

def getConfigXMLDOM():
  configXMLDoc = minidom.parse(configPath)
  return configXMLDoc

def getNMUsername():
  nmUsernameElem = getConfigXMLDOM().getElementsByTagName('node-manager-username')[0]
  return nmUsernameElem.firstChild.nodeValue

def getEncryptedNMPassword():
  nmPasswordElem = getConfigXMLDOM().getElementsByTagName('node-manager-password-encrypted')[0]
  return nmPasswordElem.firstChild.nodeValue

def getNMPassword():
  encryptionService = weblogic.security.internal.SerializedSystemIni.getEncryptionService(domainHome)
  encryption = weblogic.security.internal.encryption.ClearOrEncryptedService(encryptionService)
  return encryption.decrypt(getEncryptedNMPassword())


if serverType == "AdminServer":
  try:
    nmUsername = getNMUsername()
    nmPassword = getNMPassword()
    nmConnect(username=nmUsername,password=nmPassword, domainName=domainName, domainDir=domainHome ,nmType=nmtype, host=hostName, port=nmPort)
    nmKill(adminServerName)
    nmDisconnect()

  except Exception, e:
    dumpStack()
    nmDisconnect()
    raise Exception('Failed to stop admin server')

elif serverType == "ManagedServer":
  try:
    nmUsername = getNMUsername()
    nmPassword = getNMPassword()
    nmConnect(username=nmUsername,password=nmPassword, domainName=domainName, domainDir=domainHome ,nmType=nmtype, host=hostName, port=nmPort)
    nmKill(managedServerName)
    nmDisconnect()
  except Exception, e:
    dumpStack()
    nmDisconnect()
    raise Exception('Failed to stop managed server')

