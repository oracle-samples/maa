DRS scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  
  

Using the Disaster Recovery Setup (DRS) utils
==============================================

IMPORTANT: Verify that you have completed all the pre-requisites listed
below before using the DRS utils.

Please refer to the following whitepaper for details about the topology and set up automated by these scripts:
https://www.oracle.com/a/tech/docs/maa-soamp-dr.pdf

Pre-requisites 
--------------
  NOTE: in case you are re-running DRS see "Troubleshooting" section for specific requisites

* Ensure that your SOA stacks (WLS + Database) are fully provisioned 
  and operational at both, primary and standby, sites
* Ensure that the standby database is in **SNAPSHOT STANDBY** mode.
* Ensure that all WLS components (including NMs) are up & running at 
  the primary site.
    * Node 1:  Node Manager, Admin Server, Managed Server 1
    * Node 2:  Node Manager and Managed Server 2
* Ensure that all WLS components (including NMs) are up & running at 
  the standby site.
    * Node 1:  Node Manager, Admin Server, Managed Server 1
    * Node 2:  Node Manager and Managed Server 2

  NOTE: in case your standby WLS processes cannot start (e.g. because you have converted the standby db to physical again after provisioning the
  standby SOA but before running DRS), keep the WLS and nodemanager processes stopped in the standby site. You will need to run DRS using the flag "--skip_checks" (more 
  details below).

* Ensure that SOA infrastructure is available at both, primary and
  standby, sites. For MFT environments, check that the sample-app is avaiable at both.

* Ensure that both the mid-tier SOA nodes at the standby site can
  communicate with the primary database IP over port 1521:
  * If Data Guard was configured using OCI Dynamic Routing Gateway and remote VCN peering, 
    ensure that the standby midtier hosts can connect to primary DB private IP over port 1521.
    Ensure that appropriate ingress security rules are added to the primary database's VCN and
    that Dynamic Routing Gateway is configured in the Routing Table associated with the 
    SOA nodes subnet with destination of the primary DB's CIDR block.

  * If Data Guard nodes communicates each other with public IP addresses: 
    ensure that the standby midtier hosts can connect to primary DB public IP over port 1521.
    Add an ingress rule for each standby mid-tier SOA node public IP, TCP,port 1521 to 
    the primary database subnet's security list.
    (Ex. Source IP: 129.146.248.101/32 Protocol: TCP Port: 1521)

  You can run this check to verify the communication with primary DB from standby midtier hosts:
  java -classpath /u01/app/oracle/middleware/wlserver/server/lib/weblogic.jar utils.dbping ORACLE_THIN system <system_password> <primary_db_private_ip>:1521/<primary_db_service>

* DRS makes a backup copy of the entire secondary domain folder before modifying it.
  It is located in /u01/data/domains/<domain_name>_backup_timestamp
  This backup may be required for recovering the WLS domain before re-executing DRS 
  in case of certain failures (see section "Troubleshooting" below)

Download & Extraction
-----------------------

* DRS utils should be run on a host running Oracle Enterprise Linux 7 or 8. It is recommended to run it from one of the secondary SOA nodes.
* Download the file 'drs-mp.tar.gz' file and extract its contents using 
  the command:
    $ tar -xvzf drs-mp.tar.gz
* The 'tar' command will create a directory named 'drs_mp_soa'

  
Prepare the environment with the required Python libraries
-----------------------------------------------------------
* Read the file PREPARE_DRS_VENV.md and follow its instructions to prepare the environment for DRS utils execution.

Running the DRS utils
-------------------------
Change directory to the 'drs_mp_soa' directory and follow the instructions given below to run the DRS utils.

a) Edit the "drs_user_config.yaml" file in this directory and set up 
   all values based on your environment. If your database configuration
   uses RAC (cluster), ensure that you initialize the 'rac_scan_ip'
   variable in the configuration.
    
    **NOTE: Do not modify any files besides drs_user_config.yaml
 
b) To view the help and options available, run the DRS using the 
   command (with no options):

    $ sh drs_run.sh

c) Execute the DRS utils by using the following command and either one of 
   the options:

    $ sh drs_run.sh [--checks_only or --config_dr or --config_test_dr]
        where:
            --checks_only       run the initial checks only. This does not 
                                perform any setup actions
            --config_dr         setup DR
            --config_test_dr    setup DR and test using switchover
                                and switchback
            
    CAUTION: Using the --config_test_dr option will shut down your 
               production stack 

d) You may also additionally pass a "--skip_checks" flag to the script 
   to skip certain OPTIONAL checks: when using this flag, DRS does not check
   whether primary and standby WLS stacks are up, but it performs other mandatory checks.
   Example of usage:

    $ sh drs_run.sh --checks_only --skip_checks

    OR

    $ sh drs_run.sh --config_dr --skip_checks
    
    OR
    
    $ sh drs_run.sh --config_test_dr --skip_checks
    
    NOTE: Using the --skip_checks option is recommended if your standby WLS 
    stack components are not running (e.g. because you had already converted 
    the standby db from snapshot to physical standby, so they can't start), 
    or when you are re-executing DRS utils after an initial run 
    that has failed for some reason (see "Troubleshooting" section).

e) You may also additionally pass a "--do_not_start" flag to the script, in order to
   make DRS to skip the steps that start and verify the WLS processes in standby.
   By default (without setting this flag), the DRS toolf starts the node manager and the WLS servers in each node
   after the DR setup. It verifies that they are correctly started, it checks the secondary frontend url, 
   and then it stops the WLS servers again. This is the recommended approach, because this way the DR setup is verified by the DRS tool.

   If you provide the flag "--do_not_start", these steps are skipped. DRS will only configure DR 
   but will not start/verify the secondary WLS servers, 
   Examples of usage:

    $ sh drs_run.sh --config_dr --do_not_start
    
    OR
    
    $ sh drs_run.sh --config_dr --do_not_start --skip_checks

   This maybe needed for example, if you have to run a custom action in the standby servers post 
   DR setup but before starting the standby WLS servers.

   NOTE: if you run DRS using --do_not_start flag, you must verify later that the 
   DR has been succesfully configured in the environment, by following the steps described in 
   "Open Secondary Site for Validation" in the DR setup whitepaper.


f) During execution, the DRS logs to a log file named 
   "*logfile_<date-time-stamp>.log*".  You can monitor setup progress by 
   monitoring the contents of this file as follows:

    $ tail -f logfile_<date-time-stamp>.log

g) To monitor only a summary of the major events, you can use the 
   drs_monitor_log.sh script as follows:

    $ drs_monitor_log.sh logfile_<date-time-stamp>.log


Troubleshooting
---------------
If the DRS execution encounters errors and fails while setting up SOA 
mid-tier nodes at the standby site, you can re-execute it
after resetting the standby domain back to the original state. 
Follow these steps to restore the domain and re-run DRS:

1) Stop all WLS components (Managed Servers, Admin Servers and
   Node Managers) on all mid-tier nodes at the standby site in case they are running.
2) Restore the WLS domain on both nodes at the standby site by using the domain backup copy
   that DRS has performed. If there is no backup copy, it is because DRS did not modify the standby domain folder yet.
3) Do not try to start any component in standby midtiers, they may not start if in a 
   previous DRS run the secondary database has been converted to standby.
4) Verify that the standby database is in snapshot standby database mode.
5) Run DRS tool with the option to skip checks. For example:

    $ sh drs_run.sh --config_dr --skip_checks

