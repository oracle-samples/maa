#!/usr/bin/python
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a WLST script to update BI Integration Parameters
#

import os, sys


connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<HOSTNAME>:<OIG_OIM_ADMIN_PORT>')
msBean = ObjectName('oracle.iam:name=Discovery,type=XMLConfig.DiscoveryConfig,XMLConfig=Config,Application=oim')
biconfig = mbs.setAttribute(msBean,Attribute('BIPublisherURL','<OIG_BI_PROTOCOL>://<OIG_BI_HOST>:<OIG_BI_PORT>'))
print biconfig
disconnect()
connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<OIG_ADMIN_HOST>:<OIG_ADMIN_PORT>')
updateCred(map='oim',key='BIPWSKey',user='<OIG_BI_USER>',password='<OIG_BI_USER_PWD>')
exit()

exit
