#!/usr/bin/python
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a WLST script to update the OIMSOAIntegration MBean
#

import os, sys

connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<HOSTNAME>:<OIG_OIM_PORT>')
custom()
msBean = ObjectName('oracle.iam:name=OIMSOAIntegrationMBean,type=IAMAppRuntimeMBean,Application=oim')
params = ['<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_LBR_INT_PROTOCOL>://<OIG_LBR_INT_HOST>:<OIG_LBR_INT_PORT>/','<OIG_LBR_PROTOCOL>://<OIG_LBR_HOST>:<OIG_LBR_PORT>/','<OIG_LBR_INT_PROTOCOL>://<OIG_LBR_INT_HOST>:<OIG_LBR_INT_PORT>/','cluster:<OIG_T3>://soa_cluster','<OIG_LBR_INT_PROTOCOL>://<OIG_LBR_INT_HOST>:<OIG_LBR_INT_PORT>/ucs/messaging/webservice/']
sign = ['java.lang.String', 'java.lang.String','java.lang.String', 'java.lang.String', 'java.lang.String', 'java.lang.String', 'java.lang.String']
intgresult = mbs.invoke(msBean, 'integrateWithSOAServer', params, sign)
print intgresult
disconnect()
exit()

