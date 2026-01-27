REM
REM   Name:           crt_db_role_change_trigger.sql
REM
REM   Copyright (c) 2024 Oracle and/or its affiliates
REM   Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
REM
REM   Purpose:        This script creates the required table and role change trigger that will in tern submit a job to the database scheduler
REM                   that runs an external job.  This job executes scripts on all RAC nodes to reconfigure EBS on the DB nodes if those
REM                   scripts determine if reconfiguration is required.
REM
REM                   The apps.xxx_EBS_role_change table is an EBS CEMLI only used by these scripts and the applicatin mid tiers.  Because the
REM                   job runs on the first RAC node that transitions the database to the PRIMARY role and, that the job is asyncronous (but will
REM                   run immediately once submitted, we need to insert a row per each RAC node into this table so that as each set of scripts
REM                   complete to completion on each RAC node, they will delete the row corrosponding to their node name.  The scripts that
REM                   start application services will check for rows in this table.  When the row count is zero, they then will start application
REM                   services.
REM                   NOTE: This table will not be managed by ADOP nor undergo any edition redefinition changes.

set echo on

alter session set container = VISPRD;

drop table apps.xxx_EBS_role_change;

create table apps.xxx_EBS_role_change (
   host_name     varchar2(128),
   rolechange_date  date
);

REM  Role change database trigger must be defined at the CDB level.

alter session set container = CDB$ROOT;

CREATE OR REPLACE TRIGGER Configure_EBS_AfterRoleChange AFTER db_role_change ON DATABASE
DECLARE
  v_role VARCHAR(30);
BEGIN

  SELECT DATABASE_ROLE INTO v_role FROM V$DATABASE;

  IF v_role = 'PRIMARY' THEN

     -- Submit the job that will execute the external scripts.  The job will run immediately.
     DBMS_SCHEDULER.CREATE_JOB (
          Job_name=> 'EBS_DB_RoleChange',
          Job_type=> 'EXECUTABLE',
          Job_action => '/home/oracle/ebscdb/custom_admin_scripts/EBS_DB_RoleChange.sh',
          Enabled => TRUE
     );
     DBMS_SCHEDULER.ENABLE('EBS_DB_RoleChange');

  END IF;
END;
/

alter trigger Configure_EBS_AfterRoleChange enable;


