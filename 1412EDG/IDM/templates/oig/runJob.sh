#!/bin/bash
# Copyright (c) 2021, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example file to compile java program and Run Recon Jobs
#
export JAVA_HOME=<JAVA_HOME>
export PATH=$JAVA_HOME/bin:$PATH
export CLASSPATH=<OIG_ORACLE_HOME>/idm/oam/server/rreg/lib/commons-logging.jar:<OIG_ORACLE_HOME>/oracle_common/modules/oracle.jrf/jrf-api.jar:<OIG_ORACLE_HOME>/soa/plugins/jdeveloper/bpm/libraries/log4j-1.2.8.jar:<OIG_ORACLE_HOME>/idm/server/client/oimclient.jar:<OIG_ORACLE_HOME>/oracle_common/modules/clients/com.oracle.webservices.fmw.client.jar:<OIG_ORACLE_HOME>/idm/server/idmdf/event-recording-client.jar:<OIG_ORACLE_HOME>/idm/server/idmdf/idmdf-common.jar:<OIG_ORACLE_HOME>/idm/designconsole/ext/wlthint3client.jar:<OIG_ORACLE_HOME>/soa/soa/modules/quartz-all-1.6.5.jar:<OIG_ORACLE_HOME>/oracle_common/modules/oracle.mds/mdsrt.jar:<WORKDIR>

echo "Compiling Java Code:"
javac <WORKDIR>/runJob.java -Xlint:deprecation -Xlint:unchecked > runJob_compile.log 2> runJob_compile_err.log


java -Djava.security.policy=<WORKDIR>/lib/xl.policy -Djava.security.auth.login.config=<WORKDIR>/lib/authwl.conf -DAPPSERVER_TYPE=wls -Dweblogic.Name=oim_server1 runJob <OIG_T3>://<HOSTNAME>:<OIG_OIM_PORT>/ <LDAP_XELSYSADM_USER> <LDAP_USER_PWD> "SSO Connector Integration Group Full Reconciliation" <JOB_ARGS>

sleep 20

java -Djava.security.policy=<WORKDIR>/lib/xl.policy -Djava.security.auth.login.config=<WORKDIR>/lib/authwl.conf -DAPPSERVER_TYPE=wls -Dweblogic.Name=oim_server1 runJob <OIG_T3>://<HOSTNAME>:<OIG_OIM_PORT>/ <LDAP_XELSYSADM_USER> <LDAP_USER_PWD> "SSO Connector Integration User Reconciliation" <JOB_ARGS>

sleep 20

java -Djava.security.policy=<WORKDIR>/lib/xl.policy -Djava.security.auth.login.config=<WORKDIR>/lib/authwl.conf -DAPPSERVER_TYPE=wls -Dweblogic.Name=oim_server1 runJob <OIG_T3>://<HOSTNAME>:<OIG_OIM_PORT>/ <LDAP_XELSYSADM_USER> <LDAP_USER_PWD> "SSO Connector Integration Group Membership Full Reconciliation" <JOB_ARGS>

sleep 20

java -Djava.security.policy=<WORKDIR>/lib/xl.policy -Djava.security.auth.login.config=<WORKDIR>/lib/authwl.conf -DAPPSERVER_TYPE=wls -Dweblogic.Name=oim_server1 runJob <OIG_T3>://<HOSTNAME>:<OIG_OIM_PORT>/ <LDAP_XELSYSADM_USER> <LDAP_USER_PWD> "SSO Connector Integration Group Hierarchy Sync Full Reconciliation" <JOB_ARGS>

