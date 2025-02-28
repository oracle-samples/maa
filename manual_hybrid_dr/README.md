hybrid_dr scripts version 1.0.

Copyright (c) 2022 Oracle and/or its affiliates
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/


Using the Oracle WLS Hybrid Disaster Recovery scripts  
==================================================

Please refer to the following playbooks for details about the topology and set up automated by these scripts:  
https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html  
https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud/index.html  

IMPORTANT: Verify that you have completed all the pre-requisites listed in the appropriate paper above before using these scripts.

Summary of the scripts
=====================================

| Folder | Content |
| ------ | ------ |
| [hybrid_dr_terraform/](./hybrid_dr_terraform) | A set of terraform scripts to create the OCI resources as described in the playbook |
| [hybrid_dr_rsync_scripts/](./hybrid_dr_rsync_scripts) | A set of rsync scripts and examples to copy the file system contents to remote site, as described in the playbook |
| [others/](./others) | Other scripts referenced in the playbook |


