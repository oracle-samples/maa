#!/bin/bash


## maak8-etcd-backup.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script creates an etcd snapshot of a K8s control plane.
### This snapshot can be "applied/restored" using the maak8-etcd-restore.sh script.
### It requires/uses etcdctl, downloadable from https://etcd.io/
### It uses variables defined in maak8s.env. For this script the following variables need to be entered in 
### maak8s.env:
###	user
###		This is the OS user that will be used to ssh into the K8s controls plane nodes
###	ssh_key
###		This is the ssh key to be used to log into the the K8s controls plane nodes
### 	etcdctlhome
###		This is the directory where etcdct is installed
### The rest of the variables can be defaulted unless etcd uses different pors from the default ones 
### Usage:
###
###      ./maak8s-etcd-backup.sh [BACKUP_DIRECTORY] [LABEL] [KUBECONFIG]
### Where:
###	BACKUP_DIRECTORY:
###			This is the directory where the etcd snapshot will be stored.
###     LABEL:
###                     This is the user-provided text (inside quotes) that charaterizes the snapshot
###			It is stored as text file in the backup directory.
###	KUBECONFIG:
###			This is the complete path to the kubeconfig file used to execute kubectl commands


if [[ $# -eq 3 ]]; 
then
	export backup_root_dir=$1
	export label=$2
	export kcfg=$3
else
	echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 3, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [BACKUP_DIRECTORY] [LABEL] [KUBECONFIG]"
	echo ""
	echo "Example:  "
	echo "    $0  /backups/ \"ETCD Snapshot after first configuration \" /home/opc/.kubenew/config "
	exit 1
fi

export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "********* BACKUP OF K8s CLUSTERS BASED ON ETCD SNAPSHOT *********"
echo "Make sure you have provided the required information in the env file $basedir/maak8s.env"
echo "Also, your Kubernetes cluster must be UP for taking the backup."
echo ""
echo "Creating backup... this may take some time..."
. $basedir/maak8s.env


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

export MNODE_LIST=$(kubectl --kubeconfig=$kcfg get nodes | grep 'master\|control' | grep -v NAME | awk '{print $1}')
echo "$MNODE_LIST" > $backup_dir/mnode.log
export WNODE_LIST=$(kubectl --kubeconfig=$kcfg get nodes | grep -v 'master\|control' | grep -v NAME | awk '{print $1}')
echo "$WNODE_LIST" > $backup_dir/wnode.log

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

export first_node=$(echo $MNODE_LIST  | awk '{print $1;}')
mkdir -p /tmp/$dt
ssh -q -i $ssh_key $user@$first_node "sudo mkdir -p /tmp/$dt/"
ssh -q -i $ssh_key $user@$first_node "sudo cp /etc/kubernetes/pki/etcd/* /tmp/$dt/"
ssh -q -i $ssh_key $user@$first_node "sudo chmod a+rw /tmp/$dt/*"
scp -q -i $ssh_key $user@$first_node:/tmp/$dt/* /tmp/$dt/
sleep 5

export etcdcacert=/tmp/$dt/ca.crt 
export etcdkey=/tmp/$dt/server.key
export etcdcert=/tmp/$dt/server.crt

export ETCDMASTERNODE=$(sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL --cacert $etcdcacert --key $etcdkey --cert $etcdcert | awk -F'|' '{print $2,$6}' | grep true | awk -F':' '{print $1}')
export ETCDMASTERNODE=$(echo ${ETCDMASTERNODE//[[:blank:]]/})

echo "$ETCDMASTERNODE"> $backup_dir/etcd_master.log

for host in ${MNODE_LIST}; do
	export host_dir=$backup_dir/$host
	mkdir -p $host_dir
	echo "***************************************** Creating etcd snapshot from $host *****************************************"
	#Take backup of etcd
	sudo $etcdctlhome/etcdctl --endpoints $host:$advert_port --cacert $etcdcacert --key $etcdkey --cert $etcdcert snapshot save $host_dir/etcd-snapshot-$host.db | tee -a $backup_dir/backup.log
	#Take backup of manifests, pki and kubelet conf
	echo "Creating backup of kubernetes configuration in $host ..."
	ssh -i $ssh_key $user@$host "sudo tar -czvf /tmp/${host}-etc-kubernetes.gz /etc/kubernetes" >/dev/null 2>&1 | tee -a $backup_dir/backup.log
	ssh -i $ssh_key $user@$host "sudo cp /var/lib/kubelet/kubeadm-flags.env /tmp/${host}-kubeadm-flags.env"
	scp -q -i $ssh_key $user@$host:/tmp/${host}-kubeadm-flags.env $host_dir/
	scp -q -i $ssh_key $user@$host:/tmp/${host}-etc-kubernetes.gz $host_dir/
	#Take backup of cni
	ssh -i $ssh_key $user@$host "sudo tar -czvf /tmp/${host}-cni.gz /var/lib/cni" >/dev/null 2>&1 | tee -a $backup_dir/backup.log
	scp -q -i $ssh_key $user@$host:/tmp/${host}-cni.gz $host_dir/
	#Take backup of kubelet metadata
	ssh -i $ssh_key $user@$host "sudo tar -czvf /tmp/${host}-kubelet.gz --exclude='/var/lib/kubelet/device-plugins' --exclude='/var/lib/kubelet/pods' --exclude='/var/lib/kubelet/pod-resources'  /var/lib/kubelet" >/dev/null 2>&1 | tee -a $backup_dir/backup.log
	scp -q -i $ssh_key $user@$host:/tmp/${host}-kubelet.gz $host_dir/
	echo "Backup for $host completed!"
	echo ""
done

#Copy api server key
ssh -i $ssh_key $user@$ETCDMASTERNODE "sudo mkdir -p /tmp/sa_${dt} && sudo cp /etc/kubernetes/pki/sa.* /tmp/sa_${dt}/ && sudo chmod +r /tmp/sa_${dt}/sa.*"
scp -q -i $ssh_key $user@$ETCDMASTERNODE:/tmp/sa_${dt}/sa.* $backup_dir/

#Take a backup of etcd info
sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL  --cacert $etcdcacert --key $etcdkey --cert $etcdcert > $backup_dir/etcd_info.log
sudo $etcdctlhome/etcdctl -w table member list --endpoints $ADVERTISE_URL  --cacert $etcdcacert --key $etcdkey --cert $etcdcert  >>  $backup_dir/etcd_info.log

#Take an informational log of the kubernetes sytem: pods, nodes, services

kubectl --kubeconfig=$kcfg get pods -A -o wide > $backup_dir/kubectl-pods.log
kubectl --kubeconfig=$kcfg get nodes -o wide >> $backup_dir/kubectl-nodes.log
kubectl --kubeconfig=$kcfg get svc -A >> $backup_dir/kubectl-services.log
kubectl --kubeconfig=$kcfg get cm kubeadm-config -n kube-system -o yaml  >> $backup_dir/kubectl-kubadm-cm.yaml
kubectl --kubeconfig=$kcfg get cm -A  >> $backup_dir/all-cm.log
kubectl --kubeconfig=$kcfg cluster-info dump  >> $backup_dir/cluster-info.log
#For other users to be able to restore we allow read on all snapshots etc
sudo chmod +r -R $backup_dir

echo $label  > $backup_dir/backup_label.txt

#Cleanup

for host in ${MNODE_LIST}; do
	ssh -i $ssh_key $user@$host "sudo rm -rf /tmp/${host}-etc-kubernetes.gz"
	ssh -i $ssh_key $user@$host "sudo rm -rf /tmp/${host}-cni.gz"
	ssh -i $ssh_key $user@$host "sudo rm -rf /tmp/${host}-kubelet.gz"
done
ssh -i $ssh_key $user@$first_node "sudo rm /tmp/$dt/*"
sudo rm -rf /tmp/$dt/*
sudo rm -rf /tmp/sa
ssh -i $ssh_key $user@$ETCDMASTERNODE "sudo rm -rf /tmp/sa_${dt}/"
echo "************************************************************************************"
echo "BACKUP CREATED AT $backup_dir "
echo "************************************************************************************"

