"""
Copyright (c) 2024 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
"""
import os
import os.path
import sys
import socket
from xml.dom import minidom
import time as systime


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
wait_timeout_millis = 100000

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

def connect_nm_with_retry(nmUsername, nmPassword, domainName, domainHome, listenAddress, listenPort, nmtype, waitTimeSec=wait_timeout_millis / 1000):
    try:

        max_wait_time_sec = waitTimeSec
        current_wait_time_sec = 0
        failed = True
        while current_wait_time_sec < max_wait_time_sec:
            systime.sleep(5)

            try:
                nmConnect(username=nmUsername, password=nmPassword, domainName=domainName,
                          domainDir=domainHome, nmType=nmtype, host=listenAddress, port=int(listenPort))

                if nm():
                    failed = False
                    nmVersion()
                    break
                else:
                    current_wait_time_sec += 5
            except:
                current_wait_time_sec += 5

        if failed:
            raise Exception()

    except Exception, e:
        raise Exception('Failed connecting to node manager')


try:
  nmUsername = getNMUsername()
  nmPassword = getNMPassword()
  connect_nm_with_retry(nmUsername=nmUsername, nmPassword=nmPassword, domainName=domainName, domainHome=domainHome , listenAddress=hostName, listenPort=str(nmPort), nmtype=nmtype)
  #nmConnect(username=nmUsername,password=nmPassword, domainName=domainName, domainDir=domainHome ,nmType=nmtype, host=hostName, port=nmPort)
  nmStart(serverName)
  nmDisconnect()
except Exception, e:
  dumpStack()
  nmDisconnect()
  raise Exception('Failed to start WebLogic server')
