# Copyright (c) 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This is an example of adding Java properties to the server start scripts
#
# Usage: Not invoked directly
EXTRA_JAVA_PROPERTIES="${EXTRA_JAVA_PROPERTIES}
      -Djavax.net.ssl.trustStore=<OAM_TRUST_STORE>
      -Djavax.net.ssl.trustStorePassword=<OAM_TRUST_PWD>"
export EXTRA_JAVA_PROPERTIES
