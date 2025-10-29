#!/usr/bin/python
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a WLST script to update the Workflow Notifications
#

import os, sys

connect('<OIG_WLS_ADMIN_USER>','<OIG_WLS_PWD>','<OIG_T3>://<OIG_ADMIN_HOST>:<OIG_ADMIN_PORT>')
domainRuntime()
msBean = ObjectName('oracle.as.soainfra.config:Location=soa_server1,name=human-workflow,type=HWFMailerConfig,Application=soa-infra')
mbs.setAttribute(msBean,Attribute('HWFMailerNotificationMode','EMAIL'))
mbs.setAttribute(msBean, Attribute('ASNSDriverEmailFromAddress','<OIG_EMAIL_FROM_ADDRESS>'))
mbs.setAttribute(msBean, Attribute('ASNSDriverEmailReplyAddress','<OIG_EMAIL_REPLY_ADDRESS>'))
mbs.setAttribute(msBean, Attribute('ASNSDriverEmailRespondAddress','<OIG_EMAIL_REPLY_ADDRESS>'))

print 'Email Notifications set to : ', mbs.getAttribute(msBean,'HWFMailerNotificationMode')


disconnect()
exit()
