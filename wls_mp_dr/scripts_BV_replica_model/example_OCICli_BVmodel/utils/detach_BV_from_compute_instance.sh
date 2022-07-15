## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

export ociConfigFile=$1
export volumeAttachmentId=$2

oci --config-file $ociConfigFile compute volume-attachment detach --volume-attachment-id $volumeAttachmentId 
