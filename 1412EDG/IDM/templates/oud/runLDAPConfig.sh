export ORACLE_HOME=<OUD_ORACLE_HOME>
export JAVA_HOME=<JAVA_HOME>


LOGDIR=<WORKDIR>

action=$1
configFile=$2

if [ "configFile" = "" ] || [ "$action" = "" ]
then
   echo Usage ldapConfigTool.sh configFile action
   exit 1
fi

rm <WORKDIR>/automation.log > /dev/null 2>&1
cd $ORACLE_HOME/oud/idmtools/bin


if [ "$action" = "prepareIDStore" ]
then
   ./ldapConfigTool.sh -$action input_file=<WORKDIR>/$configFile log_level=FINEST mode=all
else
   ./ldapConfigTool.sh -$action input_file=<WORKDIR>/$configFile log_level=FINEST
fi

if [ ! "$action" = "addMissingObjectClasses" ] && [ ! "$action" = "setupOUDacl" ]
then
   mv automation.log <WORKDIR>/${action}.log
fi

exit

