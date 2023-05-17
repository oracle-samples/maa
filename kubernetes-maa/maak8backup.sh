#!/bin/bash
#SCRIPT TO CREATE A BACKUP OF CONTROL PLANE 

#ROOT DIRECTORY WITH ALL BACKUPS
export backup_root_dir=/scratch/docker/backups
#DATE AND TIME MARKER FOR DIRECTORY THAT WILL HOST THE BACKUPS
export dt=`date "+%F_%H-%M-%S"`
#BACKUP LOCATION
export backup_dir=$backup_root_dir/controlplane_$dt
#sudo ready user
export user=opc
#ssh key
export ssh_key=/home/opc/KeyWithoutPassPhraseSOAMAA.ppk
#etcdctl executable
export etcdctlhome=/scratch/docker/etcdctl/

#List of control plane nodes 
export mnode1=olk8-m1
export mnode2=olk8-m2
export mnode3=olk8-m3
export NODE_LIST="$mnode1 $mnode2 $mnode3"

export ADVERTISE_URL="$mnode1:2379,$mnode2:2379,$mnode3:2379"

export label=$1

for host in ${NODE_LIST}; do

export host_dir=$backup_dir/$host
mkdir -p $host_dir

#Take backup of etcd
sudo $etcdctlhome/etcdctl --endpoints $host:2379 --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt snapshot save $host_dir/etcd-snapshot-$host.db | tee -a $backup_dir/backup.log

#take backup of manifests, pki and kubelet conf
ssh -i $ssh_key $user@$host "sudo tar -czvf $host_dir/$host-etc-kubernetes.gz /etc/kubernetes" | tee -a $backup_dir/backup.log

#Take backup of cni
ssh -i $ssh_key $user@$host "sudo tar -czvf $host_dir/$host-cni.gz /var/lib/cni" | tee -a $backup_dir/backup.log

#Take backup of kubelet metadata
ssh -i $ssh_key $user@$host "sudo tar -czvf $host_dir/$host-kubelet.gz /var/lib/kubelet" | tee -a $backup_dir/backup.log


done

#Take a backup of etcd info
sudo $etcdctlhome/etcdctl -w table endpoint status --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt > $backup_dir/etcd_info.log
sudo $etcdctlhome/etcdctl -w table member list --endpoints $ADVERTISE_URL --cacert /etc/kubernetes/pki/etcd/ca.crt --key /etc/kubernetes/pki/etcd/server.key --cert /etc/kubernetes/pki/etcd/server.crt  >>  $backup_dir/etcd_info.log

#Take a backup of the kubernetes sytem metadata: pods, nodes, services

ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A -o wide" > $backup_dir/kubectl.log
ssh -i $ssh_key $user@$mnode1 "kubectl get nodes" >> $backup_dir/kubectl.log

ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A | grep kube-system" | awk '{print $2}' > $backup_dir/pod_list.log

#ssh -i $ssh_key $user@$mnode1 "kubectl get pods -A | grep kube-system" | awk '{print $2}' |ssh -i $ssh_key $user@$mnode1 " kubectl describe pod \$1 -n kube-system" > $backup_dir/pods_descriptions.log

#Possible ER: include pods from other ns, not only from the kube-system.Also save config maps, specially the kubeadmconfg
for pod in `cat ${backup_dir}/pod_list.log`
do
   echo $pod
   ssh -i $ssh_key $user@$mnode1 " kubectl describe pod $pod -n kube-system" > $backup_dir/${pod}.description.log
   ssh -i $ssh_key $user@$mnode1 " kubectl logs $pod -n kube-system" > $backup_dir/${pod}.logs.log
done
tar -czvf $backup_dir/all_pod_logs.gz $backup_dir/*.logs.log
rm -rf $backup_dir/*.logs.log 

#For other users to be able to restore we allow read on all snapshots etc
ssh -i $ssh_key $user@$mnode1 "sudo chmod +r -R $backup_dir"

echo $label  > $backup_dir/backup_label.txt

echo "************************************************************************************"
echo "BACKUP CREATED AT $backup_dir "
echo "************************************************************************************"

