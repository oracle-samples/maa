# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of using WLST to add logout to ADF pages
#
connect('<OAM_WLS_ADMIN_USER>','<OAM_WLS_PWD>','<OAM_T3>://<OAM_ADMIN_HOST>:<OAM_ADMIN_PORT>')
addOAMSSOProvider(loginuri="/${app.context}/adfAuthentication", logouturi="/oam/logout.html")
exit()


