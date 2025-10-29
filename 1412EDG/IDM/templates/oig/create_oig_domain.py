# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of procedures used to Create an OIG Domain
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
            if not line or line.startswith("#"):
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
        machine=oigHosts[msIndex-1].split(".")[0]
        print ("Creating Managed Server : %s " % name)
        create(name, 'Server')
        cd('/Servers/%s/' % name )
        set('ListenPort', ms_port)
        set('ListenPortEnabled',false)
        set('ListenAddress',oigHosts[msIndex-1])
        set('AdministrationPort',ms_adminPort)
        set('AdministrationPortEnabled',true)
        set('Name', name)
        set('NumOfRetriesBeforeMSIMode', 0)
        set('RetryIntervalBeforeMSIMode', 1)
        set('Cluster', cluster_name)
        set('Machine',machine)
        
        if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
            create(name,'SSL')
            cd('SSL/%s' % name)
            cmo.setEnabled(true)
            cmo.setListenPort(ms_sslPort)
        

def update_dataSource(dataSource):
    print "Updating Datasouce "+dataSource
    cd('/JdbcSystemResource/'+dataSource+'/JdbcResource/'+dataSource+'/JdbcDriverParams/NO_NAME')
    cmo.setUrl(dbConnect)
    set('PasswordEncrypted', passwords["OIG_DB_SCHEMA_PWD"])
    cd('Properties/NO_NAME/Property/user')
    user=get('Value').replace('DEV',properties["OIG_RCU_PREFIX"])
    cmo.setValue(user)
    cd('/JdbcSystemResource/'+dataSource+'/JdbcResource/'+dataSource+'/')
    create(dataSource, 'JDBCOracleParams')
    cd('JDBCOracleParams/NO_NAME_0')
    set('FanEnabled','true')

# Usage example
properties = read_properties(responseFile)
passwords = read_pwdfile(pwdFile)

appDir= properties["OIG_DOMAIN_HOME"] + '/applications'
dbConnect='jdbc:oracle:thin:@'+properties["OIG_DB_SCAN"]+":"+properties["OIG_DB_LISTENER"]+"/"+properties["OIG_DB_SERVICE"]
server=properties["OIG_DB_SCAN"].split(".",0)
oigHosts=properties["OIG_HOSTS"].split(",")
frontEndURL = properties["OIG_LBR_PROTOCOL"] + "://" + properties["OIG_LBR_HOST"] + ":" + properties["OIG_LBR_PORT"]
noManagedServers=len(oigHosts)

# Print all properties
print "Values being Used:"
for key, value in properties.items():
    print(key,value)

print "appDir="+appDir 
print "dbConnect="+dbConnect
print "FrontEnd Host: "+frontEndURL

print 'Loading Templates'
selectTemplate('Basic WebLogic Server Domain')
selectTemplate('Oracle JRF')
selectTemplate('Oracle Enterprise Manager')
selectTemplate('Oracle Identity Manager')
enableServiceTable('true')
loadTemplates()
showTemplates()

print 'Setting Domain Properties'
setOption('DomainName', properties["OIG_DOMAIN_NAME"])
setOption('JavaHome', javaHome)
setOption('AppDir',appDir)
setOption('OverwriteDomain', 'true')
#setFEHostURL("http://"+ properties["OIG_LBR_HOST"]+":80", frontEndURL, "true")

if (properties["OIG_MODE"] == "secure" ):
   set('AdministrationPortEnabled','true')
   setOption('ServerStartMode','secure')

if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
  set('ListenPortEnabled','false')
  set('SSLEnabled','true')
else:
  set('ListenPortEnabled','true')
  set('SSLEnabled','false')

print 'Setting WebLogic Admin User and Password'
cd('/Security/base_domain/User/%s' % properties["OIG_WLS_ADMIN_USER"])
cmo.setPassword(passwords["OIG_WLS_PWD"])
print 'Setting WebLogic Plug-in'
create('NO_NAME_0','WebAppContainer')
cd('/WebAppContainer/NO_NAME_0')
set('WeblogicPluginEnabled',true)

print 'Creating Machines'
createMachine (properties["OIG_ADMIN_HOST"])
for machine in oigHosts:
    if machine != properties["OIG_ADMIN_HOST"]:
        createMachine (machine)

print 'Creating Administration Server'
cd('/Server/AdminServer')
cmo.setName('AdminServer')
cmo.setAdministrationPort(int(properties["OIG_ADMIN_ADMIN_PORT"]))
cmo.setListenPort(int(properties["OIG_ADMIN_PORT"]))
if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setListenPortEnabled(false)
else:
  cmo.setListenPortEnabled(true)

cmo.setListenAddress(properties["OIG_ADMIN_HOST"])
set('Machine',properties["OIG_ADMIN_HOST"].split(".")[0])

create('AdminServer','SSL')
cd('SSL/AdminServer')
if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setEnabled(true)
else:
  cmo.setEnabled(false)

cmo.setListenPort(int(properties["OIG_ADMIN_SSL_PORT"]))

print "Enabling JDBC Persistence Stores"
enableASMAutoProv(True)
enableASMDBBasis(True)
enableJMSStoreDBPersistence(True)
enableJTATLogDBPersistence(True)

print "Setting Credentials"
cd('/')
cd('Credential/TargetStore/oim')
cd('TargetKey/keystore')
create('c', 'Credential')
cd('Credential')
set('Username', 'keystore')
set('Password', passwords["OIG_WLS_PWD"])

cd('/')
cd('Credential/TargetStore/oim')
cd('TargetKey/OIMSchemaPassword')
create('c', 'Credential')
cd('Credential')
set('Username', properties["OIG_RCU_PREFIX"] + '_OIM')
set('Password', passwords["OIG_DB_SCHEMA_PWD"])

cd('/')
cd('Credential/TargetStore/oim')
cd('TargetKey/sysadmin')
create('c', 'Credential')
cd('Credential')
set('Username', 'xelsysadm')
set('Password', passwords["OIG_WLS_PWD"])

cd('/')
cd('Credential/TargetStore/oim')
cd('TargetKey/WeblogicAdminKey')
create('c', 'Credential')
cd('Credential')
set('Username', properties["OIG_WLS_ADMIN_USER"])
set('Password', passwords["OIG_WLS_PWD"])

cd('/')
print 'Creating OIM Cluster'
create('oim_cluster', 'Cluster')
print 'Creating Policy Manager Cluster'
create('soa_cluster', 'Cluster')

print 'Configuring Managed Server oim_server1'
cd('/Server/oim_server1')
cmo.setListenPort(int(properties["OIG_OIM_PORT"]))
if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
  cmo.setListenPortEnabled(false)
else:
  cmo.setListenPortEnabled(true)

cmo.setListenAddress(oigHosts[0])
cmo.setAdministrationPort(int(properties["OIG_OIM_ADMIN_PORT"]))
set('Machine',oigHosts[0].split(".")[0])
if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
   create('oim_server1','SSL')
   cd('SSL/oim_server1')
   cmo.setEnabled(true)
   cmo.setListenPort(int(properties["OIG_OIM_SSL_PORT"]))
   assign('Server','oim_server1','Cluster', 'oim_cluster')

if noManagedServers > 1:
   print 'Creating Additional Managed Servers'
   createManagedServers( 'oim_server' , int(properties["OIG_OIM_PORT"]), 'oim_cluster', int(properties["OIG_OIM_ADMIN_PORT"]),int(properties["OIG_OIM_SSL_PORT"]))

print 'Creating SOA Managed Servers'
cd('/Server/soa_server1')
cmo.setListenPort(int(properties["OIG_SOA_PORT"]))
cmo.setListenPortEnabled(false)
cmo.setListenAddress(oigHosts[0])
cmo.setAdministrationPort(int(properties["OIG_SOA_ADMIN_PORT"]))
#cmo.setAdministrationPortEnabled(true)
set('Machine',oigHosts[0].split(".")[0])
if (properties["OIG_DOMAIN_SSL_ENABLED"] == "true" ):
   create('soa_server1','SSL')
   cd('SSL/soa_server1')
   cmo.setEnabled(true)
   cmo.setListenPort(int(properties["OIG_SOA_SSL_PORT"]))

assign('Server','soa_server1','Cluster', 'soa_cluster')

if noManagedServers > 1:
   print 'Creating Additional Managed Servers'
   createManagedServers( 'soa_server' , int(properties["OIG_SOA_PORT"]), 'soa_cluster', int(properties["OIG_SOA_ADMIN_PORT"]),int(properties["OIG_SOA_SSL_PORT"]))

print 'Creating GridLink Datasources'

allDataSources=ls('/JdbcSystemResource/', returnMap='true')
for ds in allDataSources:
    update_dataSource(ds)

allJDBCStores=ls('/JDBCStore', returnMap='true')
for js in allJDBCStores:
    cd('/JDBCStore/'+js)
    newPrefix=get('PrefixName').replace('bas','oim')
    print 'Updaing JDBC Store ' + js + ' prefix ' +newPrefix
    set('PrefixName',newPrefix)


#print 'Updating oim-mds connection pool parameters"
#cd('/JDBCSystemResource/mds-oim/JdbcResource/mds-oim/JDBCConnectionPoolParams/NO_NAME_0')
#cd('/JDBCSystemResource/mds-oim/JdbcResource/mds-oim/JDBCConnectionPoolParams/NO_NAME_0')
#set('InitialCapacity',60)
#set('MaxCapacity',200)
#set('MinCapacity',60)

print 'Will create Base domain at ' + properties["OIG_DOMAIN_HOME"]
print 'Writing base domain...'
writeDomain(properties["OIG_DOMAIN_HOME"])
closeTemplate()
exit()
