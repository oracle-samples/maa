#############################################################################
# ChangeHomePath.sh
# An include script holding the common routine that changes the oracle 
# database home path if needed when switching a standby database to primary.
#
# This is an INCLUDE file.  It is code to be included in an outer ksh
# script.  It just holds the routine ReConfig, which calls the EBS code.
#
# Note: assumes all the database instances are present in gv_instance when
# the check is done in the main script.
# 
# Requires user equivalency across all RAC nodes.
#
# No parameters passed in
#
# Rev:
# 8/23/24  Re-formed as a standard routine to access inside different scripts
# 1/15/24  DPresley Created
#############################################################################
#
ReConfig()
{
LogMsg "Started ReConfig - Database Home Reconfiguration"

LogMsg "DbName: $DbName"

# Calling script has the apps password.  Need to get the database password
GetLogon $DB_SECRET_NAME
DB_SECRET=$LOGON

PERLBIN=`dirname $ORACLE_HOME/perl/bin/perl`
LogMsg "PERLBIN = $PERLBIN"

PATH=${PERLBIN}:${PATH}

PERL5LIB=$ORACLE_HOME/perl/lib/5.32.0:$ORACLE_HOME/perl/lib/site_perl/5.32.0:$ORACLE_HOME/appsutil/perl 

# Call the EBS script txkSuncDBConfig.pl
LogMsg "Running txkSyncDBConfig.pl"
{ echo "$APPS_SECRET"; } | perl $ORACLE_HOME/appsutil/bin/txkSyncDBConfig.pl \
 -dboraclehome=$ORACLE_HOME \
 -outdir=$ORACLE_HOME/appsutil/log \
 -cdbsid=${ORACLE_SID} \
 -pdbname=${PDB_NAME} \
 -dbuniquename=${DB_UNIQUE_NAME} \
 -israc=YES \
 -virtualhostname=${VIRTUAL_HOSTNAME} \
 -logicalhostname=${LOGICAL_HOSTNAME} \
 -scanhostname=${SCAN_NAME} \
 -scanport=${SCAN_LISTENER_PORT} \
 -dbport=${DB_LISTENER_PORT} \
 -appsuser=${APPS_USERNAME} | tee -a ${LOG_OUT}


LogMsg "Running txkCfgUtlfileDir.pl with mode=setUtlFileDir"

{ echo "$APPS_SECRET"; echo "$DB_SECRET"; } | perl $ORACLE_HOME/appsutil/bin/txkCfgUtlfileDir.pl \
 -contextfile=$CONTEXT_FILE \
 -oraclehome=$ORACLE_HOME \
 -outdir=$ORACLE_HOME/appsutil/log \
 -mode=setUtlFileDir \
 -servicetype=opc | tee -a ${LOG_OUT}

LogMsg "Running txkCfgUtlfileDir.pl with mode=syncUtlFileDir"

{ echo "$APPS_SECRET"; } | perl $ORACLE_HOME/appsutil/bin/txkCfgUtlfileDir.pl \
 -contextfile=$CONTEXT_FILE \
 -oraclehome=$ORACLE_HOME \
 -outdir=$ORACLE_HOME/appsutil/log \
 -mode=syncUtlFileDir \
 -servicetype=opc | tee -a ${LOG_OUT}

LogMsg "Completed ReConfig - Database Home Reconfiguration"
}

