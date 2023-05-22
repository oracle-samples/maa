#!/bin/bash

## maak8DR-apply.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script will creat a ta backup of artifacts in an origin K8s cluster, shipt to a remote K8s cluster
### and apply/create all of them in that target cluster. Origin, target and ssh user for the operations are
### specified in the  ./maak8DR-apply.env file
### Usage:
###
###      ./maak8DR-apply.sh [NAMESPACE LIST (optional)]
### Where:
###     NAMESPACE LIST
###                     Is an optional parameter that allows specifying a list of namespaces to be replicated
### 			If no list is provided, the script will replicate all namespaces except the infrastructure
###			ones listed in exclude_list
### Example:
###	 ./maak8DR-apply.sh "traefik soans opns"
###			Copies all artifacts in the traefik, soans and opns namespaces in the origin K8s cluster to
###			the target cluster (as entereed in the maak8DR-apply.env file).  Notice that if
###			there are dependencies between namespaces it is required to use an ordered list of namespaces
###			to restore properly (i.e. list first the namespaces on which others depend)
### 	./maak8DR-apply.sh
###                     Copies all artifacts in ALL the namespaces (except the infrastructure ones listed in the 
###			./maak8DR-apply.env exclude_list variable) in the source K8s cluster to the target
###                     cluster (as entereed in the maak8DR-apply.env file). Notice that if
###			there are dependencies between namespaces it is required to use an ordered list of namespaces
###			to restore properly (i.e. list first the namespaces on which others depend)

rootdt=`date +%y-%m-%d-%H-%M-%S`
export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "**** SYNCHRONIZATION OF TWO K8s CLUSTERS BASED ON YAML EXTRACTION AND APPLY ****"
echo "Make sure you have provided the required information in the env file $basedir/maak8DR-apply.env"
. $basedir/maak8DR-apply.env

tmp_dir=/tmp/backup.$rootdt


if [[ $# -eq 0 ]]; then
        export namespace_list=
        echo "Synchronizing clusters for all namespaces except $exclude_list ..."
elif [[ $# -eq 1 ]]; then
        export namespace_list=$1
        echo "Synchronizing clusters for $namespace_list namespaces ..."
else
        echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 0 or 1 got $#"
        echo ""
        echo "Usage:"
        echo "    $0 [NAMESPACE LIST]"
        echo ""
        echo "Example:  "
        echo "    $0    "
        echo "Synchronizes all namespaces and non-namespaced artifacts $nons_artifacts_types in k8s cluster except $exclude_list"
        echo "Example:  "
        echo "    $0  'ns1 ns2 ns3'"
        echo "Synchronizes namespaces ns1, ns2, ns3 and non-namespaced artifacts $nons_artifacts_types in k8s cluster except $exclude_list"
        exit 1
fi

mkdir $tmp_dir
echo "Creating backup in source cluster..."
${basedir}/maak8-get-all-artifacts.sh ${tmp_dir} "$namespace_list"
tarball_with_path=`${basedir}/maak8-get-all-artifacts.sh ${tmp_dir} "$namespace_list" | grep "packaged at" | awk -F'packaged at' '{print $2}'`
tar_file=`basename $tarball_with_path`
echo "Backup tar: $tarball_with_path"
#echo "TAR FILE: $tar_file"
ssh -i $ssh_key_sec $user_sec@$sechost "mkdir $tmp_dir"
echo "Shipping backup to secondary..."
scp -i $ssh_key_sec ${tarball_with_path} $user_sec@${sechost}:${tmp_dir}/
scp -i $ssh_key_sec $basedir/maak8-push-all-artifacts.sh  $user_sec@$sechost:/tmp/
scp -i $ssh_key_sec $basedir/removeyamlblock.sh  $user_sec@$sechost:/tmp/
scp -i $ssh_key_sec $basedir/maak8-get-all-artifacts.sh  $user_sec@$sechost:/tmp/
scp -i $ssh_key_sec $basedir/apply-artifacts.sh  $user_sec@$sechost:/tmp/
scp -i $ssh_key_sec $basedir/maak8DR-apply.env  $user_sec@$sechost:/tmp/

ssh -i $ssh_key_sec $user_sec@$sechost "chmod +x /tmp/maak8-push-all-artifacts.sh"
ssh -i $ssh_key_sec $user_sec@$sechost "chmod +x /tmp/maak8-get-all-artifacts.sh"
ssh -i $ssh_key_sec $user_sec@$sechost "chmod +x /tmp/removeyamlblock.sh"
ssh -i $ssh_key_sec $user_sec@$sechost "chmod +x /tmp/apply-artifacts.sh"

echo "Restoring in target cluster...This may take several minutes..."
echo "Restore log can be found at $tmp_dir/restore.log in the remote node"
ssh -i $ssh_key_sec $user_sec@$sechost "/tmp/maak8-push-all-artifacts.sh $tmp_dir/$tar_file $tmp_dir >  $tmp_dir/restore.log 2>&1"
echo "*****************************RESTORED CLUSTER STATUS*****************************"
ssh -i $ssh_key_sec $user_sec@$sechost "kubectl get all -A"
ssh -i $ssh_key_sec $user_sec@$sechost "kubectl get pv -A"
ssh -i $ssh_key_sec $user_sec@$sechost "kubectl get pvc -A"
echo "All done!"


