#!/bin/bash
# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of fixing the setDomainEnv.sh file as per Support Note: 2458120.1
#
#
# Usage: not invoked Directly
#
#
export DOMAIN_HOME=<OIG_DOMAIN_HOME>


grep -q oracle.xdkjava.compatibility.version $DOMAIN_HOME/bin/setDomainEnv.sh
if [ $? -gt 0 ]
then
   echo "Updating JAVA_PROPERTIES"

   sed -i 's/DemoTrust.jks/DemoTrust.jks -Doracle.xdkjava.compatibility.version=11.1.1 /'  $DOMAIN_HOME/bin/setDomainEnv.sh

else
  echo "JAVA_PROPERTIES already complete"
fi
