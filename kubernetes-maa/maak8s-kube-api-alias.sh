#!/bin/bash


## maak8s-kube-api-alias.sh script version 1.0.
##
## Copyright (c) 2023 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

### This script adds an additional hostname alias to the control plane KUBE-API
### It updates certificvates in all control plane nodes, the kubeadm config map and also the kubeconfig file in the
### current node

### Usage:
###
###      ./maak8s-kube-api-alias.sh [HOSTANAME_ALIAS] [KUBECONFIG]
### Where:
###	HOSTANAME_ALIAS:
###			This is the new hostname to be added to the control plane "resolvable" addresses. 
###			This alias needs to be a valid DNS name or solved locally with /etc/hosts.
###	KUBECONFIG:
###			This is the complete path to the kubeconfig file used to execute kubectl commands
if [[ $# -eq 2 ]]; 
then
	export hnalias=$1
	export kcfg=$2
else
	echo ""
        echo "ERROR: Incorrect number of parameters used: Expected 3, got $#"
	echo ""
	echo "Usage:"
	echo "    $0 [HOSTANAME_ALIAS] [KUBECONFIG]"
	echo ""
	echo "Example:  "
	echo "    $0   \"newk8slbr.mycompany.com \" /home/opc/.kube/config "
	exit 1
fi
#DATE AND TIME MARKER FOR BACKUPS
export dt=`date "+%F_%H-%M-%S"`
export basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "********* ADDITION OF A NEW HOSTNAME ALIAS TO KUBE-API FRONTEND *********"
echo "Make sure you have provided the required information in the env file $basedir/maak8s.env"
echo ""
. $basedir/maak8s.env

export MNODE_LIST=$(kubectl --kubeconfig=$kcfg get nodes | grep 'master\|control' | grep -v NAME | awk '{print $1}')
export first_node=$(echo $MNODE_LIST  | awk '{print $1;}')

export kubeadmyaml=/tmp/kubeadm-$dt.yaml
export noderegyaml=$kubeadmyaml.nodereg.yaml
#export kubeadmyaml=/scratch/docker/kubeadm.yaml.test
kubectl --kubeconfig=$kcfg -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > $kubeadmyaml

if grep -q certSANs "$kubeadmyaml"; then
	echo "Some previous alias existed, adding the new one..."
	sed -i "s/  certSANs:/  certSANs:\n  - \"$hnalias\"/g" $kubeadmyaml
else 
	echo "No previous alias found, adding certSANS section..."
	sed -i "s/  extraArgs:/  certSANs:\n  - \"$hnalias\"\n  extraArgs:/g" $kubeadmyaml
fi

#Workaround for cert modification detecting endpoints
#TBD if we need also to update controlplaneendpoint
export endpoint=$(tr \\0 ' ' < /proc/"$(pgrep kubelet)"/cmdline | awk -F'--container-runtime-endpoint=' '{print $2}' |awk '{print $1}')
export apiver=$(grep apiVersion $kubeadmyaml)
sed "s|apiServer:|kind: InitConfiguration\n$apiver\nnodeRegistration:\n  criSocket: \"$endpoint\"\n---\napiServer:|g" $kubeadmyaml > $noderegyaml

for host in ${MNODE_LIST}; do
	ssh -i $ssh_key $user@$host "sudo mv /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/apiserver-$dt.crt && sudo mv /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/apiserver-$dt.key" 
	scp -q -i  $ssh_key $kubeadmyaml $user@$host:$kubeadmyaml
	scp -q -i  $ssh_key $noderegyaml $user@$host:$noderegyaml
	ssh -i $ssh_key $user@$host "sudo kubeadm init phase certs apiserver --config $noderegyaml"
done

ssh -i $ssh_key $user@$host "sudo kubeadm init phase certs apiserver --config $noderegyaml"
echo "Restarting control plane..."
$basedir/maak8s-force-stop-cp.sh "$MNODE_LIST"
sleep 15
for host in ${MNODE_LIST}; do
	echo "Restarting kubelet in $host"
	ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet"
	sleep 5
done

echo "Refreshing information in kubeadm config map form first node..."
ssh -i $ssh_key $user@$first_node "sudo kubeadm init phase upload-config kubeadm --config $noderegyaml"

echo "Done!"
export current_server=`grep server $kcfg |awk -F'//' '{print $2}' |awk -F':' '{print $1}'`
export current_port=`grep server $kcfg|awk -F':' '{print $4}'`

echo "*****************************************************************************************************"
echo "**********************************************IMPORTANT**********************************************"
echo "To verify the corect behavior with the new alias, you can replace the server entry in your kubeconfig"
echo "Your current API front end is: $current_server" 
echo "You can replace it manually executing:"
echo "	sed -i 's/$current_server/$hnalias/g' $kcfg"
echo "Optionally, you can use this script to make replacements in the rest of the Kubernetes configuration"
echo "Some of these changes will require the restart of the control plane and kubelet in the required nodes"
echo "*****************************************************************************************************"
echo "*****************************************************************************************************"
echo " "
while true; do
        read -p "Do you want this script to replace also the kube/config file, cluster-info, kube-proxy and kubeadm-config config maps? (y/n) " yn
        case $yn in
                [yY] ) echo "Replacing entries...";break;;
                [nN] ) echo "Exiting...";exit;;
                *) echo "Invalid response. Please provide a valid value (y/n)";;
        esac
done
echo "Reconfiguring config maps and restarting control plane..."
export ndt=`date "+%F_%H-%M-%S"`
export kubeconfig=/tmp/$ndt/kubeconfig-$ndt
export clusterinfo=/tmp/$ndt/clusterinfo-$ndt.yaml
export kubeproxy=/tmp/$ndt/kubeproxy-$ndt.yaml
export kubeadmconfig=/tmp/$ndt/kubeadmconfig-$ndt.yaml
mkdir -p /tmp/$ndt/
cp $kcfg $kubeconfig
kubectl --kubeconfig=$kcfg -n kube-public get configmap cluster-info -o yaml > $clusterinfo
kubectl --kubeconfig=$kcfg -n kube-system get configmap kube-proxy -o yaml > $kubeproxy
kubectl --kubeconfig=$kcfg -n kube-system get configmap kubeadm-config -o yaml > $kubeadmconfig

cp $kcfg $kcfg-$ndt-backup
cp $clusterinfo $clusterinfo-$ndt-backup
cp $kubeproxy $kubeproxy-$ndt-backup
cp $kubeadmconfig $kubeadmconfig-$ndt-backup

sed -i "/server: https/c\    server: https:\/\/$hnalias:$current_port" $clusterinfo
sed -i "/server: https/c\    server: https:\/\/$hnalias:$current_port" $kubeproxy
sed -i "/server: https/c\    server: https:\/\/$hnalias:$current_port" $kcfg
sed -i "/controlPlaneEndpoint: /c\    controlPlaneEndpoint: $hnalias:$current_port" $kubeadmconfig

$basedir/apply-artifacts.sh $clusterinfo $clusterinfo-apply-$ndt.log
$basedir/apply-artifacts.sh $kubeproxy  $kubeproxy-apply-$ndt.log
$basedir/apply-artifacts.sh $kubeadmconfig $kubeadmconfig-apply-$ndt.log
echo "Config maps and $kcfg replaced"
$basedir/maak8s-force-stop-cp.sh "$MNODE_LIST"
for host in ${MNODE_LIST}; do
	echo "Modifying local admin.conf and restarting kubelet in $host"
	ssh -i $ssh_key $user@$host "sudo cp /etc/kubernetes/admin.conf /etc/kubernetes/admin.conf-$ndt"
	ssh -i $ssh_key $user@$host "sudo sed -i \"/server: https/c\    server: https:\/\/$hnalias:$current_port\" /etc/kubernetes/admin.conf"
        ssh -i $ssh_key $user@$host "sudo systemctl restart kubelet"
        sleep 5
done
echo "Done!"
echo "Make sure that the new hostname alias $hnalias is resolvable in all the worker and control plane nodes!"
