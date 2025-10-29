# Oracle E-Business Suite Maximum Availability Architecture Disaster Recovery Scripts

     Version 1.0

Copyright (c) 2025 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

The scripts provided here are a potential starting point for implementing full-stack automation of disaster recovery site switchover, failover, and middle tier file synchronization for Oracle E-Business Suite (EBS) R12.2 that have their database deployed on Oracle Exadata database machines in Oracle Cloud Infrastructure (OCI).  They are examples.  They are not part of any Oracle product, nor are they under any warranty.  They are intended for customers to learn from and perhaps modify for their deployment.

See the overall README for these scripts, in the parent directory, EBSR12.2onOCI.

## Overview

In OCI, when the database software home is created for the standby database, there is no guarantee that the oracle home path will match that of the primary.  If, after a switchover or failover, the oracle home path is different from that at the primary, EBS tooling and run-time operations will fail.  We’ve provided a mechanism to check for this condition, and, if needed, to reset the oracle database home path and reconfigure UTL_FILE_DIR on the new primary database nodes, on switchover or failover:

* A database role change trigger that is fired when the database transitions from standby to primary.  The trigger uses DBMS_SCHEDULER to dispatch a job that runs the script EBS_DB_RoleChange.sh.  This job is configured to execute immediately.
* The script EBS_DB_RoleChange.sh, which tests to see if the database home path is the same here on the standby (new primary) as it was on the (old) primary.  If it is the same, it exits – no more work is needed.  If it is different, it inserts one row for each database instance into a custom controlling table (APPS.XXX_EBS_ROLE_CHANGE), then executes the EBS code to reconfigure the database home paths, once on each RAC node.

If reconfiguration is needed, as configuration work is completed on each RAC database node, that database node’s row in the controlling table is deleted.  The custom EBS startup script we provide for the application tier checks to be sure that table is empty when executed using “Switchover” mode, signifying the database configuration is complete and it is safe to start application services.

The first RAC instance that completes the role change transition to the PRIMARY role will fire the database role change trigger.  As this cannot be determined in advance, the directory structure must be the same on all RAC nodes and these scripts must be deployed to each RAC node.

As with the application server scripts, these scripts are written in Korn shell (ksh), use common routines / standard functions, and spawn SQL*Plus in a coroutine if needed, so that only one database connection is started.


## Using the EBS MAA DR Scripts

Please refer to the following solution playbooks for details about the Oracle E-Business Suite (EBS) topology, setup, and how to use these scripts:

* [Learn about maximum availability architecture for Oracle E-Business Suite](https://docs.oracle.com/en/solutions/learn-about-maa-for-ebs/index.html)

* [Provision and deploy a Maximum Availability Architecture solution for Oracle E-Business Suite on Oracle Cloud Infrastructure](https://docs.oracle.com/en/solutions/deploy-maa-for-ebs-on-oci/index.html)

The scripts should be placed in a common location in each database home.  In this project, we created the following directory location in our CDB home, and labeled it $SCRIPT_DIR in our .env file:
/home/oracle/ebscdb/custom_admin_scripts/VISPRD

ALWAYS test scripts thoroughly on a test environment before promoting them to a production environment.

> [!IMPORTANT] 
> Verify that you have completed all the prerequisites listed in the playbooks referenced above before testing these scripts.


## The Scripts

The scripts for starting and stopping the application with awareness of switchover, failover, and operating as a snapshot standby for testing purposes  

=====================================

| Script | Content |
| ------ | ------ |
| EBSCFG.env | Values needed to reconfigure EBS metadata post switchover or failover |
| crt_db_role_change_trigger.sql | Create the table xxx_EBS_role_change and the trigger Configure_EBS_AfterRoleChange. Execute only once per environment. |
| stdfuncs.sh | A set of standard functions – generic routines that are useful when scripting Linux, database, and EBS administrative tasks – to include in calling scripts on both the database and the application tier.  Using these common functions simplifies each working script, making the code easier to write and maintain. As this file is simply a set of common routines , it does not start with a shebang.  The calling script must have #!ksh as its first line for these routines to work properly.|
| EBS_DB_RoleChange.sh | Spawn the scripts to reconfigure EBS on the database RAC nodes if the paths changed |
| startDBServices.sh | Start any services that do not start with the PDB is opened, either because they are not managed by CRS or they are defined within a pluggable database |
| ChangeHomePath.sh | A function included in both local and remote ksh scripts, to change the database home path on switchover.  Called by both callReconfig.sh and the EBS_DB_RoleChange.sh scripts. |
| callReConfig.sh | Reconfigure the database homes on remote database nodes. |
