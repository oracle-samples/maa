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
###	 ./maak8DR-apply.sh "soans traefik opns"
###			Copies all artifacts in the soans, traefik and opns namespaces in the origin K8s cluster to
###			the target cluster (as entereed in the maak8DR-apply.env file)
### 	./maak8DR-apply.sh
###                     Copies all artifacts in the ALL the namespaces (except the infrastructure ones listed in ./maak8-get-all-artifacts.sh
###			exclude list (exclude_list kube-system kube-flannel kube-node-lease)  in the origin K8s cluster to
###                     the target cluster (as entereed in the maak8DR-apply.env file)



rootdt=`date +%y-%m-%d-%H-%M-%S`
basedir=$(dirname "$0")
export exclude_list="kube-system kube-flannel kube-node-lease"
export nons_artifacts_types="crd clusterrole clusterrolebinding"

tmp_dir=/tmp/backup.$rootdt

echo "**** SYNCHRONIZATION OF TWO K8s CLUSTERS BASED ON YAML EXTRACTION AND APPLY ****"

#echo $(dirname "$0")

if [[ $# -eq 0 ]]; then
        export namespace_list="-A"
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

echo "Make sure you have provided primary and secondary information in the env file $basedir/maak8DR-apply.env"

. $basedir/maak8DR-apply.env

ssh -i $ssh_key $user@$primhost "mkdir $tmp_dir"
scp -q -i $ssh_key $basedir/maak8-get-all-artifacts.sh  $user@$primhost:/tmp/
ssh -i $ssh_key $user@$primhost "chmod +x /tmp/maak8-get-all-artifacts.sh"
echo "Creating backup in source cluster..."
tarball_with_path=`ssh -i $ssh_key $user@$primhost "/tmp/maak8-get-all-artifacts.sh $tmp_dir \"$namespace_list\" " | grep "packaged at" | awk -F'packaged at' '{print $2}'`
tar_file=`basename $tarball_with_path`
echo "Backup tar: $tarball_with_path"
#echo "TAR FILE: $tar_file"
ssh -i $ssh_key $user@$sechost "mkdir $tmp_dir"
echo "Shipping backup to secondary..."
scp -q -3 -i $ssh_key $user@${primhost}:"${tarball_with_path}" $user@${sechost}:${tmp_dir}/
scp -q -i $ssh_key $basedir/maak8-push-all-artifacts.sh  $user@$sechost:/tmp/
scp -q -i $ssh_key $basedir/removeyamlblock.sh  $user@$sechost:/tmp/
scp -q -i $ssh_key $basedir/maak8-get-all-artifacts.sh  $user@$sechost:/tmp/

ssh -i $ssh_key $user@$sechost "chmod +x /tmp/maak8-push-all-artifacts.sh"
ssh -i $ssh_key $user@$sechost "chmod +x /tmp/maak8-get-all-artifacts.sh"
ssh -i $ssh_key $user@$sechost "chmod +x /tmp/removeyamlblock.sh"

echo "Restoring in target cluster...This may take several minutes..."
echo "Restore log can be found at $tmp_dir/restore.log in the remote node"
ssh -i $ssh_key $user@$sechost "/tmp/maak8-push-all-artifacts.sh $tmp_dir/$tar_file $tmp_dir >  $tmp_dir/restore.log 2>&1"
echo "*****************************RESTORED CLUSTER STATUS*****************************"
ssh -i $ssh_key $user@$sechost "kubectl get all -A"
ssh -i $ssh_key $user@$sechost "kubectl get pv -A"
ssh -i $ssh_key $user@$sechost "kubectl get pvc -A"
echo "All done!"


