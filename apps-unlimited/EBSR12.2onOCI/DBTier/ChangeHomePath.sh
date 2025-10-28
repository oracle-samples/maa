#############################################################################
# ChangeHomePath.sh
#
# Copyright (c) 2024 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/ 
#
# An include script holding the common routine that changes the oracle 
# database home path if needed when switching a standby database to primary.
#
# This is an INCLUDE file.  It is code to be included in an outer ksh
# script.  It just holds the routine ReConfig, which calls the EBS code.
# It does not need a shebang, as it is simply a part of a larger program.
#
# Note: assumes all the database instances are present in gv_instance when
# the check is done in the main script.
# 
# Requires user equivalency across all RAC nodes.
#
# No parameters passed in
#
# Rev:
# 8/23/24  Re-formed as a standard routine to execute from different scripts
# 1/15/24  Created
#############################################################################
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

# If logical hostname is passed in, call txkSyncDBConfig.pl with the
# -logicalhostname parameter, else call it without this parameter.
if [ "${LOGICAL_HOSTNAME}" == "" ];
then
   # Call the EBS script txkSyncDBConfig.pl
   LogMsg "Running txkSyncDBConfig.pl to configure with physical hostname."
   { echo "$APPS_SECRET"; } | perl $ORACLE_HOME/appsutil/bin/txkSyncDBConfig.pl \
    -dboraclehome=$ORACLE_HOME \
    -outdir=$ORACLE_HOME/appsutil/log \
    -cdbsid=${ORACLE_SID} \
    -pdbname=${PDB_NAME} \
    -dbuniquename=${DB_UNIQUE_NAME} \
    -israc=YES \
    -virtualhostname=${VIRTUAL_HOSTNAME} \
    -scanhostname=${SCAN_NAME} \
    -scanport=${SCAN_LISTENER_PORT} \
    -dbport=${DB_LISTENER_PORT} \
    -appsuser=${APPS_USERNAME} | tee -a ${LOG_OUT}
else
   LogMsg "Running txkSyncDBConfig.pl to configure with logical hostname."
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
fi

if [ $? -ne 0 ]; then
   LogMsg "txkSynDBConfig.pl returned an error"
   exit 1
fi
LogMsg "Running txkCfgUtlfileDir.pl with mode=setUtlFileDir"

{ echo "$APPS_SECRET"; echo "$DB_SECRET"; } | perl $ORACLE_HOME/appsutil/bin/txkCfgUtlfileDir.pl 
 -contextfile=$CONTEXT_FILE \
 -oraclehome=$ORACLE_HOME \
 -outdir=$ORACLE_HOME/appsutil/log \
 -mode=setUtlFileDir \
 -servicetype=opc | tee -a ${LOG_OUT}
if [ $? -ne 0 ]; then
   LogMsg "txkCfgUtlfileDir.pl mode setUtlFileDir returned an error"
   exit 1
fi

LogMsg "Running txkCfgUtlfileDir.pl with mode=syncUtlFileDir"

{ echo "$APPS_SECRET"; } | perl $ORACLE_HOME/appsutil/bin/txkCfgUtlfileDir.pl \
 -contextfile=$CONTEXT_FILE \
 -oraclehome=$ORACLE_HOME \
 -outdir=$ORACLE_HOME/appsutil/log \
 -mode=syncUtlFileDir \
 -servicetype=opc | tee -a ${LOG_OUT}
if [ $? -ne 0 ]; then
   LogMsg "txkCfgUtlfileDir.pl mode syncUtlFileDir returned an error"
   exit 1
fi

LogMsg "Completed ReConfig - Database Home Reconfiguration"
}

