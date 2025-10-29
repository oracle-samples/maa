# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of procedures used to Create an OAM Domain
#
# Usage: Not invoked directly
import os, sys, getopt

def usage():

    print "Usage:"
    print "wlst.sh create_oig_domain.py -r responsefile -p passwordfile -j javaHome\n"
    sys.exit(2)

if __name__=='__main__' or __name__== 'main':

    try:
        opts, args = getopt.getopt(sys.argv[1:], "r:p:j:", ["responsfile=", "passwordfile=","javahome"])

    except getopt.GetoptError, err:
        print str(err)
        usage()

    responseFile = ''
    pwdFile = ''
    javaHome= ''

    for opt, arg in opts:
        if opt == "-r":
            responseFile = arg
        elif opt == "-p":
            pwdFile = arg
        elif opt == "-j":
            javaHome = arg

    if responseFile == "":
        print "Missing \"-r responsfile\" parameter.\n"
        usage()
    elif pwdFile == "":
        print "Missing \"-p passwordfile\" parameter.\n"
        usage()
    elif javaHome == "":
        print "Missing \"-j javahome\" parameter.\n"
        usage()

def read_properties(file_path):
    properties = {}

    with open(file_path, 'r') as file:
        for line in file:
            # Ignore empty lines and comments
            line = line.strip()
            if not line.startswith("OAM"):
                continue

            # Split the line into key and value
            key, value = line.split("=", 1)
            properties[key.strip()] = value.strip()

    return properties

def read_pwdfile(file_path):
    passwords = {}

    with open(file_path, 'r') as file:
        for line in file:
            # Ignore empty lines and comments
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Split the line into key and value
            key, value = line.split("=", 1)
            passwords[key.strip()] = value.strip()

    return passwords

def createMachine(host_name):
    print ('Creating Machine:' + host_name)
    machine=host_name.split(".")[0]
    cd('/')
    create(machine,'UnixMachine')
    cd('Machine/' + machine)
    create(machine, 'NodeManager')
    cd('NodeManager/' + machine)
    set('ListenAddress',host_name)

def createManagedServers(managedNameBase, ms_port, cluster_name, ms_adminPort, ms_sslPort):
    for index in range(0, noManagedServers-1):
        cd('/')
        msIndex = index+2
        cd('/')
        name = '%s%s' % (managedNameBase, msIndex)
        machine=oamHosts[msIndex-1].split(".")[0]
        print ("Creating Managed Server : %s " % name)
        create(name, 'Server')
        cd('/Servers/%s/' % name )
        set('ListenPort', ms_port)
        set('ListenPortEnabled',false)
        set('ListenAddress',oamHosts[msIndex-1])
        set('AdministrationPort',ms_adminPort)
        set('AdministrationPortEnabled',true)
        set('Name', name)
        set('NumOfRetriesBeforeMSIMode', 0)
        set('RetryIntervalBeforeMSIMode', 1)
        set('Cluster', cluster_name)
        set('Machine',machine)
        #cmo.setWeblogicPluginEnabled(true)
        create(name,'SSL')
        cd('SSL/%s' % name)
        cmo.setEnabled(true)
        cmo.setListenPort(ms_sslPort)
        

def update_dataSource(dataSource):
    print "Updating Datasouce"+dataSource
    cd('/JdbcSystemResource/'+dataSource+'/JdbcResource/'+dataSource+'/JdbcDriverParams/NO_NAME')
    print dataSource
    cmo.setUrl(dbConnect)
    set('PasswordEncrypted', passwords["OAM_DB_SCHEMA_PWD"])
    cd('Properties/NO_NAME/Property/user')
    user=get('Value').replace('DEV',properties["OAM_RCU_PREFIX"])
    cmo.setValue(user)
    cd('/JdbcSystemResource/'+dataSource+'/JdbcResource/'+dataSource+'/')
    create(dataSource, 'JDBCOracleParams')
    cd('JDBCOracleParams/NO_NAME_0')
    set('FanEnabled','true')

def remove_coherence():

    cd('/Clusters/oam_cluster')
    cmo.setCoherenceClusterSystemResource(None)
    cd('/CoherenceClusterSystemResources/defaultCoherenceCluster')
    cmo.removeTarget(getMBean('/Clusters/oam_cluster'))
    cd('/Clusters/policy_cluster')
    cmo.setCoherenceClusterSystemResource(None)
    cd('/CoherenceClusterSystemResources/defaultCoherenceCluster')
    cmo.removeTarget(getMBean('/Clusters/policy_cluster'))

# Read Property files
properties = read_properties(responseFile)
passwords = read_pwdfile(pwdFile)

appDir= properties["OAM_DOMAIN_HOME"] + '/applications'
dbConnect='jdbc:oracle:thin:@'+properties["OAM_DB_SCAN"]+":"+properties["OAM_DB_LISTENER"]+"/"+properties["OAM_DB_SERVICE"]
server=properties["OAM_DB_SCAN"].split(".",0)
oamHosts=properties["OAM_HOSTS"].split(",")
noManagedServers=len(oamHosts)

# Print all properties
print "Values being Used:"
for key, value in properties.items():
    print(key,value)

print "appDir="+appDir 
print "dbConnect="+dbConnect



print 'Loading Templates'
selectTemplate('Basic WebLogic Server Domain')
selectTemplate('Oracle JRF')
selectTemplate('Oracle Enterprise Manager')
selectTemplate('Oracle Access Management Suite')
enableServiceTable('true')
loadTemplates()
showTemplates()

print 'Setting Domain Properties'
setOption('DomainName', properties["OAM_DOMAIN_NAME"])
setOption('JavaHome', javaHome)
setOption('AppDir',appDir)
setOption('ServerStartMode',properties["OAM_MODE"])
setOption('OverwriteDomain', 'true')

if (properties["OAM_MODE"] == "secure" ):
   setOption('ServerStartMode','secure')
   set('AdministrationPortEnabled','true')

if (properties["OAM_DOMAIN_SSL_ENABLED"] == "true" ):
  set('ListenPortEnabled','false')
  set('SSLEnabled','true')
else:
  set('ListenPortEnabled','true')
  set('SSLEnabled','false')

print 'Setting WebLogic Admin User and Password'
cd('/Security/base_domain/User/%s' % properties["OAM_WLS_ADMIN_USER"])
cmo.setPassword(passwords["OAM_WLS_PWD"])
print 'Setting WebLogic Plug-in'
create('NO_NAME_0','WebAppContainer')
cd('/WebAppContainer/NO_NAME_0')
set('WeblogicPluginEnabled',true)


print 'Creating Machines'
createMachine (properties["OAM_ADMIN_HOST"])
for machine in oamHosts:
    if machine != properties["OAM_ADMIN_HOST"]:
        createMachine (machine)

print 'Creating Administration Server'
cd('/Server/AdminServer')
cmo.setName('AdminServer')
#cmo.setAdministrationPortEnabled(true)
cmo.setAdministrationPort(int(properties["OAM_ADMIN_ADMIN_PORT"]))
cmo.setListenPort(int(properties["OAM_ADMIN_PORT"]))

if (properties["OAM_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setListenPortEnabled(false)
else:
  cmo.setListenPortEnabled(true)

cmo.setListenAddress(properties["OAM_ADMIN_HOST"])
set('Machine',properties["OAM_ADMIN_HOST"].split(".")[0])

create('AdminServer','SSL')
cd('SSL/AdminServer')
if (properties["OAM_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setEnabled(true)
else:
  cmo.setEnabled(false)

cmo.setListenPort(int(properties["OAM_ADMIN_SSL_PORT"]))

cd('/')
print 'Creating OAM Cluster'
create('oam_cluster', 'Cluster')
print 'Creating Policy Manager Cluster'
create('policy_cluster', 'Cluster')

print 'Configuring Managed Server oam_server1'
cd('/Server/oam_server1')
cmo.setListenPort(int(properties["OAM_OAM_PORT"]))
if (properties["OAM_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setListenPortEnabled(false)
else:
  cmo.setListenPortEnabled(true)

cmo.setListenAddress(oamHosts[0])
cmo.setAdministrationPort(int(properties["OAM_OAM_ADMIN_PORT"]))
cmo.setAdministrationPortEnabled(true)
set('Machine',oamHosts[0].split(".")[0])
create('oam_server1','SSL')
cd('SSL/oam_server1')
if (properties["OAM_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setEnabled(true)
else:
  cmo.setEnabled(false)

cmo.setListenPort(int(properties["OAM_OAM_SSL_PORT"]))
assign('Server','oam_server1','Cluster', 'oam_cluster')

if noManagedServers > 1:
   print 'Creating Additional Managed Servers'
   createManagedServers( 'oam_server' , int(properties["OAM_OAM_PORT"]), 'oam_cluster', int(properties["OAM_OAM_ADMIN_PORT"]),int(properties["OAM_OAM_SSL_PORT"]))

print 'Creating Policy Manager Managed Servers'
cd('/Server/oam_policy_mgr1')
cmo.setListenPort(int(properties["OAM_POLICY_PORT"]))
cmo.setListenPortEnabled(false)
cmo.setListenAddress(oamHosts[0])
cmo.setAdministrationPort(int(properties["OAM_POLICY_ADMIN_PORT"]))
cmo.setAdministrationPortEnabled(true)
set('Machine',oamHosts[0].split(".")[0])
create('oam_policy_mgr1','SSL')
cd('SSL/oam_policy_mgr1')
if (properties["OAM_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setEnabled(true)
else:
  cmo.setEnabled(false)

cmo.setListenPort(int(properties["OAM_POLICY_SSL_PORT"]))

assign('Server','oam_policy_mgr1','Cluster', 'policy_cluster')

if noManagedServers > 1:
   print 'Creating Additional Managed Servers'
   createManagedServers( 'oam_policy_mgr' , int(properties["OAM_POLICY_PORT"]), 'policy_cluster', int(properties["OAM_POLICY_ADMIN_PORT"]),int(properties["OAM_POLICY_SSL_PORT"]))

print "Removing Default Coherence Cluster"
remove_coherence()

print 'Creating GridLink Datasources'

allDataSources=ls('/JdbcSystemResource/', returnMap='true')
for ds in allDataSources:
    update_dataSource(ds)

print 'Will create Base domain at ' + properties["OAM_DOMAIN_HOME"]
print 'Writing base domain...'
writeDomain(properties["OAM_DOMAIN_HOME"])
closeTemplate()
exit()
