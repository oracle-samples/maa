#!/bin/ksh
################################################################################
# Name: startEBS.sh
#
# Copyright (c) 2025 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# Purpose: Start EBS application tier in various ways, depending on need.
#          The basic tasks:
#          a. Configure the EBS CONTEXT_FILE *
#          b. Run autoconfig
#          c. Start EBS application services
#          d. Make sure replication is enabled
#          e. Make sure replication is complete
#          f. Block until database configuration is complete
#
# * Note: Customize this for:
#          - your configuration of the EBS CONTEXT_FILE in ConfigContext routine
#          - your background rsync scripts in the EnableReplication routine
#
#          The calling choices:
#          n: Normal: does c and d above
#          t: Test (standby): does a, b, and c above
#          s: Switchover: does a, e, b, c, and d above
#
# Usage: startEBS.sh [arguments]
#        n) Normal:
#           - Start EBS application services
#           - Make sure replication is enabled
#        t) Test (standby):
#           - Make sure the DB is in SNAPSHOT STANDBY mode
#           - Configure CONTEXT_FILE for snapshot standby
#           - Run autoconfig
#           - Start EBS application services
#        s) Switch this environment to production;
#           - Block until any required database configuration is complete
#           - Make sure there are no rsync processes running
#           - Configure CONTEXT_FILE for production
#           - Run autoconfig
#           - Start EBS application services
#           - Make sure file system replication to new standby is enabled
#
# ASSUMPTIONS: User has privileges to run EBS admin scripts.
#              User's environment is already set for EBS
#             ($NE_BASE/../EBSapps.env run has been executed)
#
# Errors: A non-zero value is returned for bad arguments, inability to
#         connect, ...
#
# Revisions:
# Date        What
# 09/10/2024  Consolidated earlier scripts into one
##########################################################################
# ParseArgs:
# Parse the command line arguments
#
#  Input: command line arguments
# Output: run proffile set, determining which routines are executed
# Return: exit 1 if arguments are no good
##########################################################################
ParseArgs()
{
#
# Make sure at least 1 argument is present
if [ $# -lt 1 ]
then
   echo "$0: ERROR: You have entered insufficient arguments"
   Usage
   exit 1
fi
# make sure the parameter passed was correct
if [[ $1 = "n" || $1 = "t" || $1 = "s" ]]
then
   break
else
   echo "$0: ERROR: You have entered an incorrect argument"
   Usage
   exit 1
fi

#
# They sent in an n, t, or s, which will drive behavior
#
runPlan=$1

}

################################################################################
# Usage:
# Standard usage clause
################################################################################
Usage()
{
echo "Usage: startEBS.sh [mode]"
echo "Mode can be:"
echo "   n = Normal startup.  Start EBS and make sure replication is enabled."
echo "   t = Test: Start the environment as snapshot"
echo "   s = Switch: Do EBS-side switchover to make this environment production."
echo ""
}

################################################################################
# SetEnv
# Get environment variables, standard include routines
#
# Input:  None
# Output: Environments set for the run
# Return: Exit 1 if can't find environment files, etc.
################################################################################
SetEnv()
{
# Include the basic "where am I" environment settings
if [ ! -f ${SCRIPT_DIR}/ebsAppTier.env ]; then
   echo "Cannot find the file ${SCRIPT_DIR}/ebsAppTier.env."
   exit 1
fi

. ${SCRIPT_DIR}/ebsAppTier.env

# Include the standard functions routines
if [ ! -f ${SCRIPT_DIR}/stdfuncs.sh ]; then
   echo "Cannot find the standard functions script (stdfuncs.sh)"
   exit 1
fi

. $SCRIPT_DIR/stdfuncs.sh

EnvSetup
LOG_OUT=${LOG_DIR}/${HostName}_startEBS_${TS}.log

# Make sure the the apps env. is already set
if [ ! -f $NE_BASE/../EBSapps.env ]; then
   LogMsg "EBS environment is not set.  Cannot find the file EBSapps.env."
   LogMsg "NE_BASE: $NE_BASE"
   exit 1
fi
}

################################################################################
# GetCreds
# Get EBS and FMW credentisls needed in this run
#
# Input:  None
# Output: The creds we need, set
# Return: 1 if can't find one of the users referenced (GetLogon breaks out)
################################################################################
GetCreds()
{
LogMsg "Getting EBS credentials"
GetLogon $APPS_SECRET_NAME
APPS_SECRET=$LOGON

GetLogon $WLS_SECRET_NAME
WLS_SECRET=$LOGON
}

################################################################################
# ConnectDB
# Launch the coroutine.  Need for t and s only
#
# Input:  None
# Output: SQL*Plus child process initiated 
# Return: 1 if can't start sqlplus in the background
################################################################################
ConnectDB()
{
LogMsg "ConnectDB: LaunchCoroutine"

# Start sqlplus in coroutine, logged in as apps user
LaunchCoroutine APPS $APPS_SECRET $PDB_TNS_CONNECT_STRING

LogMsg "SQLPlus coroutine started"
}

################################################################################
# WaitDBConfig
# Part of switchover: wait until all database homes have been configured.
#
# The switchover process on the database side puts a row into a custom table for
# each DB node.  Then as each node fixes its config files, it removes its entry.
# If the work is not needed, the table is not populated.  If it is needed,
# as the work is done on each EBS instance its row is removed, until the table
# is empty.  When the table is empty work can proceed on the middle tiers.
#
# Potential source of a hang, since it's theoretically possible for rows to
# be inserted and not deleted, but that would be an issue that needs to be
# resolved.
#
# Input:  None
# Output: Number of DB instances needing reconfig, sleep time, dividing line
# Return: 1 if can't start sqlplus in the background
#           if no sleep time
#           if $sql is empty
################################################################################
WaitDBConfig()
{
LogMsg "Wait for database home reconfiguration to complete"

sql="select ltrim('host: ' || host_name) from apps.xxx_EBS_role_change;"
CkRunDB 5

LogMsg "Database tier configuration complete - ok to proceed."
}

################################################################################
# StandbyCheck
# Make sure the database is in snapshot standby mode
#
# Input:  None
# Output: None
# Return: 1 if database is not in SNAPSHOT STANDBY mode
################################################################################
StandbyCheck()
{
LogMsg "Making sure the database is in snapshot standby mode"

sql="select rtrim(database_role) from v\$database;"
dbMode=`ExecSql "$sql"`

if [ ${dbMode} != "SNAPSHOT STANDBY" ]; then 
   LogMsg "Database is not in SNAPSHOT STANDBY mode"
   LogMsg "Cannot do snapshot standby testing"
   exit 1
fi

LogMsg "StandbyCheck: Succeeded"
}

################################################################################
# ConfigContext
# Configure the context file for snapshot standby testing or for production
# when switching this site to prod
#
# NOTE: Add more commands if you need to change the value of more settings
#       (e.g., port numbers)
#
# Input:  Env file to use to switch configuration values in EBS's CONTEXT_FILE
# Output: CONTEXT_FILE reconfigured as requested
# Return: 1 if env file can't be found
################################################################################
ConfigContext()
{
envFile=$1

LogMsg "envFile: ${SCRIPT_DIR}/${envFile}"

if [ ! -f ${SCRIPT_DIR}/${envFile} ]; then 
   LogMsg "ConfigContext: No env file specified or file not found"
   exit 1
else
   LogMsg "ConfigContext: Setting environment"
fi

. $SCRIPT_DIR/$envFile

# Back up the context file
LogMsg "Backing up CONTEXT_FILE ${CONTEXT_FILE}"
cp $CONTEXT_FILE $CONTEXT_FILE.'date +"%Y%m%d"'

# These commands are each one line (this wraps in your display)
# hostname used in the SSL CA certificate.
LogMsg "Set s_webentryhost ${webentryhost}"
$RUN_BASE/EBSapps/comn/util/jdk32/jre/bin/java -classpath $RUN_BASE/EBSapps/comn/java/classes:$RUN_BASE/FMW_Home/Oracle_EBS-app1/shared-libs/ebs-appsborg/WEB-INF/lib/ebsAppsborgManifest.jar oracle.apps.ad.context.UpdateContext $CONTEXT_FILE s_webentryhost ${webentryhost}
if [ $? -ne 0 ]; then
   LogMsg "UpdateContext returned an error for s_webentryhost"
   exit 1
fi

LogMsg "Set s_webentrydomain ${webentrydomain}"
$RUN_BASE/EBSapps/comn/util/jdk32/jre/bin/java -classpath $RUN_BASE/EBSapps/comn/java/classes:$RUN_BASE/FMW_Home/Oracle_EBS-app1/shared-libs/ebs-appsborg/WEB-INF/lib/ebsAppsborgManifest.jar oracle.apps.ad.context.UpdateContext $CONTEXT_FILE s_webentrydomain ${webentrydomain}
if [ $? -ne 0 ]; then
   LogMsg "UpdateContext returned an error for s_webentrydomain"
   exit 1
fi

# s_webport is the http port for the application server on the application tier.
LogMsg "Set s_webport ${webport}"
$RUN_BASE/EBSapps/comn/util/jdk32/jre/bin/java -classpath $RUN_BASE/EBSapps/comn/java/classes:$RUN_BASE/FMW_Home/Oracle_EBS-app1/shared-libs/ebs-appsborg/WEB-INF/lib/ebsAppsborgManifest.jar oracle.apps.ad.context.UpdateContext $CONTEXT_FILE s_webport ${webport}
if [ $? -ne 0 ]; then
   LogMsg "UpdateContext returned an error for s_webport"
   exit 1
fi

# s_active_webport is used for the front-end load balancer.
LogMsg "Set s_active_webport ${active_webport}"
$RUN_BASE/EBSapps/comn/util/jdk32/jre/bin/java -classpath $RUN_BASE/EBSapps/comn/java/classes:$RUN_BASE/FMW_Home/Oracle_EBS-app1/shared-libs/ebs-appsborg/WEB-INF/lib/ebsAppsborgManifest.jar oracle.apps.ad.context.UpdateContext $CONTEXT_FILE s_active_webport ${active_webport}
if [ $? -ne 0 ]; then
   LogMsg "UpdateContext returned an error for s_active_webport"
   exit 1
fi

# EBS login page.
LogMsg "Set s_login_page ${login_page}"
$RUN_BASE/EBSapps/comn/util/jdk32/jre/bin/java -classpath $RUN_BASE/EBSapps/comn/java/classes:$RUN_BASE/FMW_Home/Oracle_EBS-app1/shared-libs/ebs-appsborg/WEB-INF/lib/ebsAppsborgManifest.jar oracle.apps.ad.context.UpdateContext $CONTEXT_FILE s_login_page ${login_page}
if [ $? -ne 0 ]; then
   LogMsg "UpdateContext returned an error for s_login_page"
   exit 1
fi

# The base URL that EBS will use for redirects back through the load balancer.
LogMsg "Set s_external_URL ${external_URL}"
$RUN_BASE/EBSapps/comn/util/jdk32/jre/bin/java -classpath $RUN_BASE/EBSapps/comn/java/classes:$RUN_BASE/FMW_Home/Oracle_EBS-app1/shared-libs/ebs-appsborg/WEB-INF/lib/ebsAppsborgManifest.jar oracle.apps.ad.context.UpdateContext $CONTEXT_FILE s_external_URL ${external_URL}
if [ $? -ne 0 ]; then
   LogMsg "UpdateContext returned an error for s_external_URL"
   exit 1
fi

LogMsg "CONTEXT_FILE reconfigured"
}

################################################################################
# RunAutoConfig
# Run autoconfig on all application servers
#
# Input:  None
# Output: EBS configuration updated
# Return: 1 if can't start sqlplus in the background
################################################################################
RunAutoConfig()
{
LogMsg "Running autoconfig on all application servers"

{ echo $APPS_SECRET; }| perl $AD_TOP/bin/adconfig.pl -contextfile=$CONTEXT_FILE -parallel promptmsg=hide | tee -a ${LOG_OUT}

# Check for success
if [ $? -ne 0 ]; then
  LogMsg "$AD_TOP/bin/adconfig.pl reported failure."
  exit 1
fi

LogMsg "Completed: RunAutoConfig."
}

################################################################################
# StartServices
# Run autoconfig on all application servers
#
# Input:  None
# Output: EBS application and middle tiers started on all app servers
# Return: 1 if can't start sqlplus in the background
################################################################################
StartServices()
{
LogMsg "Starting EBS on all application servers"

{ echo "APPS"; echo $APPS_SECRET; echo $WLS_SECRET; } | $ADMIN_SCRIPTS_HOME/adstrtal.sh -msimode | tee -a ${LOG_OUT}

# Did adstrtal report failure?
if [ $? -ne 0 ]; then
  LogMsg "$ADMIN_SCRIPTS_NAME/adstrtal.sh reported failure."
  exit 1
fi

LogMsg "Completed: StartServices."
}

################################################################################
# CkRsync
# DB shutdown on switchover is supposed to finish and stop rsync background
# processes.  This checks to see if rsync is still running.  At this point in
# the flow, it should not be running, so exit with error if it is.
#
# Input:  None
# Output: None
# Return: 1 if rsync processes are running somewhere.
################################################################################
CkRsync()
{
LogMsg "Make sure replication is not running anywhere."

if [ -f "${SCRIPT_DIR}/ebsrsync.lck" ]; then
   LogMsg "CkRsync: There's an rsync process running on `cat $SCRIPT_DIR/ebsrsync.lck`"
   LogMsg "CkRsync: Wait until database side is completely ready before switching" 
   LogMsg "         to this site."
   exit 1
fi

LogMsg "Completed: CkRsync."
}

################################################################################
# EnableReplication
# Make sure replication is enabled with this site as primary
#
# Input:  None
# Output: None
# Return: 1 if can't start sqlplus in the background
################################################################################
EnableReplication()
{
LogMsg "Make sure replication is enabled with this site as source"

# Customize this for your replication scripts
${SCRIPT_DIR}/enable_ebs_rsync.sh ${SCRIPT_DIR}/slowFiles.env
${SCRIPT_DIR}/enable_ebs_rsync.sh ${SCRIPT_DIR}/fastFiles.env

LogMsg "Completed: EnableReplication."
}

################################################################################
# Execution starts here.
################################################################################

ParseArgs $*
# Leave ParseArgs with runPlan set to n, t, or s

SetEnv

LogMsg "runPlan: $runPlan"

LogMsg "startEBS.sh: Started"

GetCreds

case $runPlan in
   n) LogMsg "Normal startup"
      StartServices
      EnableReplication
      ;;
   t) LogMsg "Start for snapshot testing"
      ConnectDB
      StandbyCheck
      # Note: hard-coded env file reference
      ConfigContext web_entry_test.env
      RunAutoConfig
      StartServices
      ;;
   s) LogMsg "Switch to this environment"
      ConnectDB
      WaitDBConfig
      CkRsync
      # Note: hard-coded env file reference
      ConfigContext web_entry_prod.env
      RunAutoConfig
      StartServices
      EnableReplication
      ;;
   *) Usage
      exit 1
      ;;
esac

LogMsg "Completed: startEBS.sh"


