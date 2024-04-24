"""
Copyright (c) 2019 Oracle and/or its affiliates. All rights reserved.
"""
import os
import sys
import socket

clusterName = sys.argv[1]
adminURL = os.getenv('WLS_ADMIN_URL')
wlsadminconfigfile = os.getenv('WLS_USER_ADMIN_CONFIGFILE')
wlsadminkeyfile = os.getenv('WLS_USER_ADMIN_KEYFILE')

try:
  connect(userConfigFile=wlsadminconfigfile, userKeyFile=wlsadminkeyfile, url=adminURL)
  shutdown(name=clusterName,entityType='Cluster',timeOut=120)
  disconnect()
except Exception, e:
  dumpStack()
  disconnect()
  raise Exception('Failed to start weblogic cluster')
