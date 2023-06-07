#!/bin/bash


## maak8s-etcd-backup.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script creates an etcd snapshot of a K8s control plane.
### This snapshot can be "applied/restored" using the maak8-etcd-restore.sh script.
### It uses variables defined in maak8s.env
### It requires installation of etcdctl https://etcd.io/
### Usage:
###
###      ./maak8s-etcd-backup.sh [BACKUP_DIRECTORY] [LABEL]
### Where:
###	BACKUP_DIRECTORY:
###			This is the directory where the ectd snapshot will be stored.
###     LABEL:
###                     This is the user-provided text (inside quotes) that charaterizes the snapshot
###			It is stored as text file in the backup directory

export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "********* BACKUP OF K8s CLUSTERS BASED ON ETCD SNAPSHOT *********"
echo "Make sure you have provided the required information in the env file $basedir/maak8s.env"
echo "The Kubernetes cluster must be UP for taking the backup"


. $basedir/maak8s.env

if [[ $# -eq 2 ]]; 
then
	export backup_root_dir=$1
	export label=$2
else
	echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 2, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [BACKUP_DIRECTORY] [LABEL]"
	echo ""
	echo "Example:  "
	echo "    $0  /backups/ \"ETCD Snapshot after first configuration \" "
	exit 1
fi

# Check dependencies
if [[ ! -x "${etcdctlhome}/etcdctl" ]]; then
	echo "Error. etcdctl not found or not executable. Make sure you have installed etcdctl and provided the right path to it."
	exit 1
fi

#DATE AND TIME MARKER FOR DIRECTORY THAT WILL HOST THE BACKUPS
export dt=`date "+%F_%H-%M-%S"`

#BACKUP LOCATION
export backup_dir=$backup_root_dir/etcd_snapshot_$dt
mkdir -p $backup_dir

export MNODE_LIST=$(ssh -i $ssh_key $user@$bastion_node "kubectl get nodes" | grep master | grep -v NAME | awk '{print $1}')
echo "$MNODE_LIST" > $backup_dir/mnode.log
export WNODE_LIST=$(ssh -i $ssh_key $user@$bastion_node "kubectl get nodes" | grep -v master | grep -v NAME | awk '{print $1}')
echo "$MNODE_LIST" > $backup_dir/wnode.log

#Contruction of etcd URLS
INIT_URL=""

for I in $MNODE_LIST;do
    buff="$I=https://$I:2380,"
    INIT_URL=${INIT_URL:+$INIT_URL}$buff
done
INIT_URL=${INIT_URL:0:-1}
echo "$INIT_URL"> $backup_dir/init_url.log

ADVERTISE_URL=""

for I in $MNODE_LIST;do
    buff="$I:2379,"
    ADVERTISE_URL=${ADVERTISE_URL:+$ADVERTISE_URL}$buff
done
ADVERTISE_URL=${ADVERTISE_URL:0:-1}
echo "$ADVERTISE_URL" > $backup_dir/advertise_url.log

export ETCDMASTERNODE=$(ssh -i $ssh_key $user@$bastion_node "sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt" | awk -F'|' '{print $2,$6}' | grep true | awk -F':' '{print $1}')
export ETCDMASTERNODE=$(echo ${ETCDMASTERNODE//[[:blank:]]/})

echo "$ETCDMASTERNODE"> $backup_dir/etcd_master.log

for host in ${MNODE_LIST}; do
	export host_dir=$backup_dir/$host
	mkdir -p $host_dir
	#Take backup of etcd
	sudo $etcdctlhome/etcdctl --endpoints $host:$advert_port --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt snapshot save $host_dir/etcd-snapshot-$host.db | tee -a $backup_dir/backup.log
	#take backup of manifests, pki and kubelet conf
	ssh -i $ssh_key $user@$host "sudo tar -czvf $host_dir/$host-etc-kubernetes.gz /etc/kubernetes" | tee -a $backup_dir/backup.log
	#Take backup of cni
	ssh -i $ssh_key $user@$host "sudo tar -czvf $host_dir/$host-cni.gz /var/lib/cni" | tee -a $backup_dir/backup.log
	#Take backup of kubelet metadata
	ssh -i $ssh_key $user@$host "sudo tar -czvf $host_dir/$host-kubelet.gz /var/lib/kubelet --exclude='/var/lib/kubelet/device-plugins' --exclude='/var/lib/kubelet/pods' --exclude='/var/lib/kubelet/pod-resources' " | tee -a $backup_dir/backup.log
done

#Take a backup of etcd info
sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt > $backup_dir/etcd_info.log
sudo $etcdctlhome/etcdctl -w table member list --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt  >>  $backup_dir/etcd_info.log

#Take an informational log of the kubernetes sytem: pods, nodes, services

ssh -i $ssh_key $user@$bastion_node "kubectl get pods -A -o wide" > $backup_dir/kubectl-pods.log
ssh -i $ssh_key $user@$bastion_node "kubectl get nodes" >> $backup_dir/kubectl-nodes.log
ssh -i $ssh_key $user@$bastion_node "kubectl get svc -A" >> $backup_dir/kubectl-services.log


#For other users to be able to restore we allow read on all snapshots etc
ssh -i $ssh_key $user@$bastion_node "sudo chmod +r -R $backup_dir"

echo $label  > $backup_dir/backup_label.txt

echo "************************************************************************************"
echo "BACKUP CREATED AT $backup_dir "
echo "************************************************************************************"

