#############################################################################
# std_funcs.sh
# Collection of standard functions. 
#
# Rev:
# 8/13/24       MPratt  Updated for simple cloud tooling
# 7/19/99       MPratt  added GetLogon
# 1/17/96       MPratt  added MultiThread and CkRun
# 8/23/95       MPratt  created
#############################################################################
# GetLogon:
# Get the password for the user secret name passed in.  Set the variable
# LOGON. In the calling routine, set the intended password variable.
# 
#############################################################################

GetLogon()
{
uname=$1

SECRET_OCID=$(oci vault secret list -c $COMPARTMENT_OCID --raw-output --query "data[?\"secret-name\" == '$uname'].id | [0]")

LOGON=$(oci secrets secret-bundle get --raw-output --secret-id $SECRET_OCID --query "data.\"secret-bundle-content\".content" | base64 -d )

if [ $? != 0 ]; then
   LogMsg "GetLogon: Failed."
   LogMsg "Compartment: $COMPARTMENT_OCID"
   LogMsg "User name: $uname"
   exit 1
fi
}

#############################################################################
# EnvSetup:
# Set up the unix and oracle environment as needed...
#
# Do we need this?  Hohw should it be adjusted for modern era?
# Removed export of ORAENV_ASK=NO
# 
#############################################################################

EnvSetup()
{
# set TS to the timestamp.  Used to create the output directory for the run.
TS=`date +"%Y%m%d_%H%M%S"`

# Set up the oracle environment.
# ORAENV_ASK=NO; . oraenv
}
  
#############################################################################
# GetDbName
# Get the database name for this oracle sid
#
# Input:  None
# Output: Sets DbName variable
# Return: None
#############################################################################

GetDbName()
{
  sql="select name from v\$database;"
  DbName=`ExecSql "${sql}"`
}

#############################################################################
# LaunchCoroutine:
# Start a sqlplus session to pipe commands to from this shell session.
#
# Input:  DB password secret needs to be set prior to calling
# Output: None, but the coroutine stays up and running
# Return: exits if error is detected.
#############################################################################

LaunchCoroutine()
{
uname=$1
pwd=$2
cxHost=$3

cxString=$uname/$pwd@$cxHost

if [[ ! "$uname" || ! "$pwd" || ! "$cxHost" ]]; then
  LogMsg "Usage: LaunchCoroutine user_name password host"
  LogMsg "User name: $uname"
  LogMsg "Password: $pwd"
  LogMsg "Host: $cxHost"
  LogMsg "Connection string: $cxString"
  exit 1
fi

# Verify the Oracle connection 
sqlplus -silent <<! >$TMP_FILE 2>&1
$cxString
!

if [ $? != 0 ]; then
    LogMsg "LaunchCoroutine: Unable to connect to Oracle."
    LogMsg "LaunchCoroutine: Verify password, state of database"
    cat $TMP_FILE | LogMsg 
    exit 1
fi

# Launch the coroutine itself.
sqlplus -s |&
echo -e "${cxString}" >&p
echo -e "set scan off\n" >&p
echo -e "set heading off\n" >&p
echo -e "set feedback off\n" >&p
echo -e "set pagesize 0\n" >&p
echo -e "set linesize 2000\n" >&p
echo -e "set long 65535\n" >&p
echo -e "select '<-DONE->' from dual;\n" >&p

tmp="$IFS"
IFS=""

# read from the coroutine's output 'til you see <-DONE->
while [ "1" ]; do
    read answer <&p
    if [ "$answer" = "<-DONE->" ]; then
      break
    fi
done


IFS="$tmp"

rm $TMP_FILE

}


#############################################################################
# ExecSql
# Send a SQL statement to the sqlplus coroutine; return the result to the
# calling routine.
#
#  Input: sql statement
# Output: result of sql statement
# Return: none
#############################################################################

ExecSql ()
{
# send the statement to the coroutine with the "-p"
  echo -e "$1\n" >&p
  echo -e "select '<-DONE->' from dual;\n" >&p

  tmp="$IFS"
  IFS=""

# read from the coroutine's output 'til you see <-DONE->
  while [ "1" ]; do
    read answer <&p

    if [ "$answer" = "<-DONE->" ]; then
      break
    else
      echo -e "$answer"
    fi
  done

  IFS="$tmp"
}


#############################################################################
# DbConnect
# Connect to a different database.  This needs a different routine than
# ExecSql.
#
#  Input: connect string
# Output: result of sql statement
# Return: none
#############################################################################

DbConnect ()
{

# send the statement to the coroutine with the "-p"
  printf -p "$1"
  printf -p "select '<-DONE->' from dual;"

  tmp="$IFS"
  IFS=""

# read from the coroutine's output 'til you see <-DONE->
  while [ "1" ]; do
    read -p answer
 
    if [ "$answer" = "<-DONE->" ]; then
      printf "$answer"
      break
    fi

    if [ "$answer" = "ORA-03114: not connected to ORACLE" ]; then
      LogMsg "DbConnect: ERROR: $answer" 
      exit 1
    fi

    if [ "$answer" = "ERROR: ORA-01034: ORACLE not available" ]; then
      LogMsg "DbConnect: ERROR: $answer" 
      exit 1
    fi

  done

  IFS="$tmp"
}


##############################################################################
#
#  Description: Echo a message to stdout and the run's log file.
#
#        Usage: LogMsg "message text"
#
#        Input: Message text
#         Note: If message text = "-p", then input is read from stdin
#               (so you can pipe to this).
#
#       Output: Writes the timestamp, host name, database name, and message to 
#               stdout and to LOG_OUT.  Requires LOG_OUT be already defined 
#
#       Return: None
#
##############################################################################

LogMsg ()
{
  LogMsgTimestamp=`date +"%m%d %T"`

# If they are piping the message in to print from a command
# (eg, cat file | LogMsg), this requires resetting the interfield
# separator,  After that, we read the message piece by piece from stdin.
  if [ "$1" = "-p" ]; then
    tmp="$IFS"
    IFS=""
    while read message
    do
      printf "${LogMsgTimestamp}|${HostName}|${DbName}| $message\n"
      if [ ! -z "$LOG_OUT" ]; then
         printf "${LogMsgTimestamp}|${HostName}|${DbName}| $message\n" >> $LOG_OUT
      fi
    done
    IFS="$tmp"

# Not piping anything to the message - just text passed straight in
  else
    printf "${LogMsgTimestamp}|${HostName}|${DbName}| $1\n"
    if [ ! -z "$LOG_OUT" ]; then
       printf "${LogMsgTimestamp}|${HostName}|${DbName}| $1\n" >> $LOG_OUT
    fi
  fi
}

##############################################################################
# CkRun
# monitor running processes to see if any are still running.
#
#  Input: 1: Unique thing to check on a ps line (required)
#         2: number of seconds to sleep between checks (required)
#         3: S if the run is to be relatively Silent
# Output: None.
# Return: Returns control when all monitored processes are complete.
##############################################################################
CkRun()
{
ckit=$1
thislong=$2
silent=$3
LogMsg "CkRun: Monitoring for $ckit"

if [ "$ckit" = "" ] || [ "$thislong" = "" ]; then
   LogMsg: "CkRun: ERROR: Insufficient arguments."
   exit 1
fi

while true
do
   if [ "$silent" != "S" ]; then
      ps -ef | grep $ckit | grep -v grep | grep -v ckrun
   fi
   matches=`ps -ef | grep $ckit | grep $$ | grep -v grep | wc -l`
   ts=`date +%m/%d/%y.%H:%M:%S`
   printf "$ts: $matches matches"
   printf "==================================================================="
   if [ $matches = 0 ]; then
      break;
   fi
   sleep $thislong
done

LogMsg "CkRun: Returning control to calling routine."
}


##############################################################################
# MultiThread
# Submit multiple tasks in the background.  "Mark time" until they are all
# complete, then return control to the calling routine.
#
# You provide a file which has command lines for the tasks, one task per line.
# These lines are "nohup'd" and run in the background.  Control is returned
# to your calling routine when all the tasks are complete.
#
# You limit the number of tasks which can be run at once, and you provide a
# unique piece of info to "grep" for on a ps -ef line, to use to count the
# number of running tasks and determine whether or not there are tasks still
# running.
#
# Possible "gotchas": if you are vi'ing or otherwise accessing something
# which puts your "unique" grep field on the ps command line, this routine
# WILL NOT return control to the calling routine!
#
#  Input: 1: name of a file which holds commands to run.  one line per command.
#         2: max # processes to run at once
#         3: unique part of the command line to "grep" for when determining
#            how many of these processes are running
#         4: number of seconds to sleep between checks for task completion
#         5: verbose mode (yes/no)
# Output: Your tasks are complete.
# Return: exit 1 if incomplete info is provided.
##############################################################################
MultiThread()
{
tasks=$1
max_processes=$2
differentiator=$3
sleep_time=$4

LogMsg "MultiThread: Starting multi-threaded execution of $tasks."
LogMsg "MultiThread: No more than $max_processes will run at once."
LogMsg "MultiThread: Using $differentiator for unique ps search."

# read the tasks from the file.  for each one:
cat $tasks | while read i
do
   LogMsg "MultiThread: Starting $i"
   nohup $i &
# count the number of jobs running already.
   matches=`ps -ef | grep $differentiator | grep $$ | grep -v grep | \
                grep -v ckrun | wc -l`
# if the number of jobs running is >= max_processes, fall into this loop.
# otherwise go through the outer loop again to kick off another job.
   until [ $matches -lt $max_processes ]
   do
      sleep $sleep_time
      matches=`ps -ef | grep $differentiator | grep $$ | grep -v grep | \
                grep -v ckrun | wc -l`
      LogMsg "MultiThread: $matches tasks running..."
   done
done

# Run the monitor.  It finishes when the tasks are done.  Need this,
# even though the jobs are kicked off when needed, as when the above loop
# is done there are still tasks running.  We can't return control to the
# calling routine until they are complete.
CkRun $differentiator $sleep_time S

LogMsg "MultiThread: Tasks complete.  Returning control to calling routine."
}


##############################################################################
# initialize common variables.  this is NOT inside a function so it gets
# executed right away.
##############################################################################
TMP=/tmp
TMP_FILE=$TMP/TMP_FILE.$$
