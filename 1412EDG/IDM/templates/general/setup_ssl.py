#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example script to update a domain to use customer keystores
#
import os, sys, getopt
def usage():

    print "Usage:"
    print "wlst.sh configure_domain.py -d domain -k keystore -c type -t truststore -a Cert Alias -p password -n node manager password\n"
    sys.exit(2)


if __name__=='__main__' or __name__== 'main':

    try:
        opts, args = getopt.getopt(sys.argv[1:], "d:k:c:t:a:p:n:", ["domain=", "keystore=", "truststore=", "alias=", "password=", "nmpassword="])

    except getopt.GetoptError, err:
        print str(err)
        usage()

    domain = ''
    keystore = ''
    truststore = ''
    alias = ''
    password = ''
    nmpassword = ''
    certtype = ''

    for opt, arg in opts:
        if opt == "-d":
            domain = arg
        elif opt == "-k":
            keystore = arg
        elif opt == "-t":
            truststore = arg
        elif opt == "-a":
            alias = arg
        elif opt == "-p":
            password = arg
        elif opt == "-n":
            nmpassword = arg

    if domain == "":
        print "Missing \"-d domain\" parameter.\n"
        usage()
    elif keystore == "":
        print "Missing \"-k keystore\" parameter.\n"
        usage()
    elif truststore == "":
        print "Missing \"-t truststore\" parameter.\n"
        usage()
    elif alias == "":
        print "Missing \"-a keystore alias\" parameter.\n"
        usage()
    elif password == "":
        print "Missing \"-p keystore password\" parameter.\n"
        usage()
    elif nmpassword == "":
        print "Missing \"-n nodemanager password\" parameter.\n"
        usage()

print 'domain=' + domain

readDomain(domain)
allServers=ls('/Servers', returnMap='true')
for server in allServers:
    cd('/Servers/%s/' % server)
    print 'Configuring SSL for server :' + server
    if alias == "host":
        certAlias = cmo.getMachine().getName()
    else:
        certAlias = alias

    print '   Cert Alias :' + certAlias

    cmo.setKeyStores('CustomIdentityAndCustomTrust')
    cmo.setCustomIdentityKeyStoreFileName(keystore)
    cmo.setCustomIdentityKeyStoreType('pkcs12')
    cmo.setCustomIdentityKeyStorePassPhraseEncrypted(password)
    cmo.setCustomTrustKeyStoreFileName(truststore)
    cmo.setCustomTrustKeyStoreType('pkcs12')
    cmo.setCustomTrustKeyStorePassPhraseEncrypted(password)
    cd('SSL/%s/' % server)
    cmo.setServerPrivateKeyAlias(certAlias)
    cmo.setServerPrivateKeyPassPhraseEncrypted(password)
    cmo.setHostnameVerificationIgnored(true);


    #cmo.getServerKeyFileName()

# Set Node Manager User Name and Password

domainName=ls('/SecurityConfiguration',returnMap='true')
cd('/SecurityConfiguration/%s/' % domainName[0])
cmo.setNodeManagerUsername('admin')
cmo.setNodeManagerPasswordEncrypted(nmpassword)
updateDomain()
exit()

