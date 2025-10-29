# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of a WLST script to set the connection pool parameters on the oamDS Datasource
#
connect('<OAM_WLS_ADMIN_USER>','<OAM_WLS_PWD>','<OAM_T3>://<OAM_ADMIN_HOST>:<OAM_ADMIN_PORT>')
edit()
startEdit()
cd('/JDBCSystemResources/oamDS/JDBCResource/oamDS/JDBCConnectionPoolParams/oamDS')
cmo.setInitialCapacity(800)
cmo.setMinCapacity(800)
cmo.setMaxCapacity(800)
save()
activate(block="true")
exit()


