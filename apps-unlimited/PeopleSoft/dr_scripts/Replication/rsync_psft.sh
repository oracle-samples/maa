############################################################################
#!/bin/sh
# File name:    rsync_psft.sh    Version 1.0
#
# Copyright (c) 2022 Oracle and/or its affiliates
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
#
# Description:  rsync the file system / directory defined in the run env.
#               file.  If the -f is used, this will cause the script to 
#               perform a FORCED rsync.  The -f option should only be used 
#               in situations where a forced rsync is required such as when
#               a site failover is required but the file systems at both 
#               sites are still intact.  
# 
# Usage:        rsync_psft.sh <fully qualified name of run env file> [ -f ]
# 
# Errors:       No run environment file specified
#               Cannot find run environment file
# 
# Revisions:
# Date       Who       What
# 7/1/2023   DPresley  Created
############################################################################

if [ $# -eq 0 ]
then
    echo "No run env. file supplied.  Please provide a run env. file."
    echo "Usage:     rsync_psft.sh <run env file> [ -F|f ]"
    echo "If a forced rsync is required, use -f."
    echo "Example:   rsync_psft.sh fs1"
    exit -1
fi

if  [ ! -f "$1" ]
then
     echo "File $1 does not exist."
     exit -1
fi

x=$2
FORCE_RSYNC=0
RSYNC_DISABLED=0

if [ ${#x} -ne 0 ]; then
     if [ $x = "-f" ] || [ $x = "-F" ]; then
          FORCE_RSYNC=1
     else
          echo "Invalid argument $x"
          exit 1
     fi
fi

source $SCRIPT_DIR/psrsync.env
source $1

pcount=0

# Check to see if rsync is disabled.

if [ -f "${SCRIPT_DIR}/.${FS_ALIAS}_rsync_disabled" ]
then
     RSYNC_DISABLED=1
fi

if [ ${RSYNC_DISABLED} = 1 ] && [ ${FORCE_RSYNC} = 1 ]; then

     proceed=""
     while [[ -z ${proceed} ]];
     do
          read -p "Rsync is disabled for ${FS_ALIAS} (${SOURCE_RSYNC_DIR}). OK to continue? [Y|y|N|n] :" proceed
          [[ ${proceed} = 'Y' || ${proceed} = 'y' || ${proceed} = 'N' || ${proceed} = 'n' ]] && break
          proceed=""
     done
     if [[ ${proceed} = 'N' || ${proceed} = 'n' ]]; then
          echo "User response was N.  Exiting..."
          exit 0
     else
          echo "User response was Y.  Proceeding with FORCED rsync..."
     fi

fi

if [ ${RSYNC_DISABLED} = 1 ] && [ ${FORCE_RSYNC} = 0 ]; then
     date >> ${LOG_DIR}/${LOG_FILE_NAME}
     echo "PeopleSoft rsync is disabled for ${FS_ALIAS} (${SOURCE_RSYNC_DIR}). Re-enable with enable_psft_rsync.sh." >> ${LOG_DIR}/${LOG_FILE_NAME}
     exit 0
fi

# If rsync is enabled and we are not forcing an rsync, check to see what role the site is in.  If not in the PRIMARY role, then exit.

if [ ${FORCE_RSYNC} = 0 ]; then
     SITE_ROLE=$( ${SCRIPT_DIR}/get_site_role.sh | egrep "PRIMARY|PHYSICAL STANDBY|SNAPSHOT STANDBY" )
     if [ "${SITE_ROLE}" != "PRIMARY" ]; then
          date >> ${LOG_DIR}/${LOG_FILE_NAME}
          echo "This site is in the ${SITE_ROLE} role and not in the PRIMARY role.  Rsync will not be performed."  >> ${LOG_DIR}/${LOG_FILE_NAME}
          exit 0
     fi
fi

# Run rsync on the file system/directory passed in to this script - unless one
# is already running for this file system.
# Exit if there is an rsync process already running for this file system.

pcount=$(ps -elf | grep "rsync -avzh --progress ${SOURCE_RSYNC_DIR}" | grep -v grep | wc -l)

if [[ ${pcount} -gt 0 ]]
then
    date >> ${LOG_DIR}/${LOG_FILE_NAME}
    echo "psft_rsync.sh is already running." >> ${LOG_DIR}/${LOG_FILE_NAME}
    exit 1
fi

date >> ${LOG_DIR}/${LOG_FILE_NAME}
[[ ${FORCE_RSYNC} = 0 ]] && echo "Site role is: ${SITE_ROLE}" >> ${LOG_DIR}/${LOG_FILE_NAME}
[[ ${FORCE_RSYNC} = 0 ]] && echo "Running rsync..."  >> ${LOG_DIR}/${LOG_FILE_NAME}
[[ ${FORCE_RSYNC} = 1 ]] && echo "Running rsync (FORCED)..."  >> ${LOG_DIR}/${LOG_FILE_NAME}
echo " FS Alias: ${FS_ALIAS} "  >> ${LOG_DIR}/${LOG_FILE_NAME}
echo " Source: ${SOURCE_RSYNC_DIR} "  >> ${LOG_DIR}/${LOG_FILE_NAME}
echo " Target: ${TARGET_RSYNC_DIR} " >> ${LOG_DIR}/${LOG_FILE_NAME}
echo "" >> ${LOG_DIR}/${LOG_FILE_NAME}

( time rsync -avzh --progress ${SOURCE_RSYNC_DIR}/ ${USER}@${TARGET_HOST}:${TARGET_RSYNC_DIR}/ ) >> ${LOG_DIR}/${LOG_FILE_NAME} 2>&1
echo "##################################" >> ${LOG_DIR}/${LOG_FILE_NAME}

exit 0
