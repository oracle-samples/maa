# Oracle E-Business Suite Maximum Availability Architecture Disaster Recovery Scripts

     Version 1.0

Copyright (c) 2025 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.

## Overview

The scripts provided here are a potential starting point for implementing full-stack automation of disaster recovery site switchover, failover, and middle tier file synchronization for Oracle E-Business Suite (EBS) R12.2 that have their database deployed on Oracle Exadata database machines in Oracle Cloud Infrastructure (OCI).  They are examples.  They are not part of any Oracle product, nor are they under any warranty.  They are intended for customers to learn from and perhaps modify for their deployment.

The files for this project fall into the following categories:

1.	Environment files holding configuration details
2.	Scripts to set up database structures needed for the process
3.	Scripts to configure the database nodes during switchover if necessary, executed via a database rol change trigger
4.	Scripts that replicate middle tier file system contents from one site to another
5.	Wrapper scripts that call the EBS startup and shutdown scripts as well as managing file system replication and application configuration, within the context of simple startup/shutdown, standby testing, and site role transition
6.	A set of standard functions that make the scripted tasks easier to implement and maintain

The wrapper scripts can be used by the OCI Full Stack Disaster Recovery (FSDR) service to automate switchover and failover.

Note: Korn shell (KSH) was used for these scripts, as it provides the ability to use a coroutine – a process that is forked by the main shell script but not spawned to be fully separate.  The KSH coroutine remains an attached “child” of the outer KSH script, able to receive requests from the outer script and return information to the outer script.  In this case, the outer script forks a SQL*Plus session as a coroutine.  The SQL*Plus session remains in place for the duration of the execution life of the shell script.  This removes the overhead of repeatedly spawning SQL*Plus for every single database request.


## Prerequisites

These requirements must be in place to implement the scripts:
1.	Logical hostnames - this simplified, reduced-outage method of switching between sites relies on logical hostnames for both the application and database tiers at both the primary and secondary sites.
2.	OCI command line interface (OCI CLI) must be installed and configured on all servers hosting or accessing the database or application tier file systems, at each region
3.	Region-local OCI vaults - To keep passwords secret, all required passwords must be stored in region-local OCI vaults that can be accessed by the OCI CLI.
4.	Cross-site user equivalency - A pair of application servers (one from each region) need to have user equivalency configured, to allow passwordless rsync synchronization.


## Using the EBS MAA DR Scripts

Please refer to the following solution playbooks for details about the Oracle E-Business Suite (EBS) topology, setup, and how to use these scripts:

* [Learn about maximum availability architecture for Oracle E-Business Suite](https://docs.oracle.com/en/solutions/learn-about-maa-for-ebs/index.html)

* [Provision and deploy a Maximum Availability Architecture solution for Oracle E-Business Suite on Oracle Cloud Infrastructure](https://docs.oracle.com/en/solutions/deploy-maa-for-ebs-on-oci/index.html)

ALWAYS test these scripts on a test environment before promoting them to a production environment.

> [!IMPORTANT] 
> Verify that you have completed all the prerequisites listed in the playbooks referenced above before testing these scripts.


## Structure

The scripts are grouped into these folders:  

| Folder | Content |
| ------ | ------ |
| AppTier | Wrapper scripts for startup and shutdown and rsync, standard functions, and .env files |
| DBTier | Scripts to set up database structures, configure database nodes during switchover if needed, standard functions, and .env files |


