"""
Copyright (c) 2024 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
"""
import os
import sys
import socket
from xml.dom import minidom

domainName = os.getenv('WLS_DOMAIN_NAME')
domainHome = os.getenv('WLS_DOMAIN_HOME')
configPath = domainHome + "/config/config.xml"

hostName=socket.getfqdn()
nmPort = int(os.getenv('NM_PORT'))
nmtype = os.getenv('NM_TYPE')

adminURL = os.getenv('WLS_ADMIN_URL')
wlsadminconfigfile=os.getenv('WLS_USER_ADMIN_CONFIGFILE')
wlsadminkeyfile=os.getenv('WLS_USER_ADMIN_KEYFILE')

serverName=sys.argv[1]

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


try:
  nmUsername = getNMUsername()
  nmPassword = getNMPassword()
  nmConnect(username=nmUsername,password=nmPassword, domainName=domainName, domainDir=domainHome ,nmType=nmtype, host=hostName, port=nmPort)
  nmKill(serverName)
  nmDisconnect()

except Exception, e:
  dumpStack()
  nmDisconnect()
  raise Exception('Failed to stop server')
