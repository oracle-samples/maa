Oracle MAA K8s Disaster Protection scripts  
Copyright (c) 2023 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

Using the Oracle MAA K8s Disaster Protection scripts   
=================================================================================================================

This directory contains scripts and utilities to replicate  K8s clusters between two regions. Image replication/protection is expected to be provided separately (*). Two different approaches are used:

1.-DR based on K8s cluster extraction and re-apply: Maintain two different clusters in primary and secondary use "tooling" to extract artifacts from a source K8s cluster and replicate to a target K8s cluster. This model is characterized by the following:

-   The clusters in primary and standby are NOT THE SAME
-   Cluster node labels, allocations etc are not taken care of by the framework. It just “redeploys” selected artifacts to a secondary cluster
-   Flexibility in primary and secondary: each K8s cluster may be running different applications and each may be using different resources
-   The possibility of not using an exact mirror is considered risky since workload may need to be throttled on switchover depending the system resources in secondary
-   Very easy to launch (it does not have any requirements on the clusters per se)
-   Possible inconsistencies may arise if not all dependencies are replicated exactly
-   Better RPO (for configuration data, runtime data is mainly stored in the DB or file system separately)
-   This approach, however, does not protect against control plane failures per se (some "etcd/kube-api protection" is still required)


2.-DR based on etcd restore: Copy etcd snapshots and required K8s configuration files across regions and restore etcd in secondary from the primary copy. This model is characterized by the following:
 - Total consistency: provided that the appropriate images and storage mounts are also present in the secondary location, a copy of the etcd contents guarantees that not only all the K8s control plane configuration and deployments etc are mirrored, but also the settings for pods (mem, cpu etc). This requires however that the secondary is an exact physical mirror or primary (number of worker nodes, control plane nodes, mount points resources available etc), i.e. there should not be scaled down mirror in secondary since settings like CPU and MEM allocations will be copied over
-   Low RTO but with RPO implications (for configuration data, runtime data is mainly stored in the DB or file system separately): the recover time objective is low if periodic copies of etcd are performed/scheduled. The secondary location just needs to start pods on switchover to resume operation (provided the appropriate DNS or re-routing of requests is done). The RPO for configuration data is driven by the frequency in configuration replication. If frequent config changes are applied in primary some of them may be left behind if etcd replication does not happen very frequently.
-   There are also secrets and certs that need to be replicated as well (although not expected to change as frequently as other etcd and applications configuration (details in sections bellow)
-   More complex to set up as it requires control plane and worker nodes to use the same hostname alias in both reegions

DR based on re-apply scripts 
--------------
The excution is pretty simple: Enter values for source and target bastions/control nodes in maak8DR-apply.env (nodes that can execute kubectl against the source and target k8s clusters respectively). Execute maak8DR-apply.sh with list of namespaces to replicate as arguments, Ex:

[opc@olk8-m1 ~]$ ./maak8DR-apply.sh "opns soans test default"

This will extract-from-source-k8s and apply-to-target-k8s all the required artifacts in the "opns soans test default" namespaces. Refer to this Oracle Architecture Center Playbook for details about the replication operations: https://docs.oracle.com/en/solutions/kubernetes-artifact-snapshot-dr/index.html 

The following table provides a summary of the utilities

  | Script name  | Description |
| ------------- | ------------- |
| [maak8DR-apply.env](./maak8DR-apply.env) | This script needs to be updated with the IP of the primary and secondary nodes (running kubectl against primary and secondary K8s clusters) and the ssh user and ssh key to access those nodes (need to be the same). |
| [maak8DR-apply.sh](./maak8DR-apply.sh) | This is the main script which calls tot he other ones to extract, ship, clenaup and apply K8s cluster artifacts |
| [maak8-get-all-artifacts.sh](./maak8-get-all-artifacts.sh) | This script is used to extract the yaml files from the primary cluster. |
| [maak8-push-all-artifacts.sh](./maak8-push-all-artifacts.sh) | This script is used to apply all the yamls files extracted from primary in the pertaininn namespaces |
| [removeyamlblock.sh](./removeyamlblock.sh) | This script cleans up information that cannot be applied directly to the target cluster. |
| [apply-artifacts.sh](./apply-artifacts.sh) | This script cleans up information that cannot be applied directly to the target cluster. |

DR based on etcd restore scripts 
--------------
  The approach and scripts work only in kubeadm K8s clusters. Each script provides automation for different parts of the DR setup and lifecycle of a disaster protection system. 
  The following table provides a summary of the utilities

  | Script name  | Description |
| ------------- | ------------- |
| [maak8s.env](./maak8s.env) | This script needs to be cusotomized in each region with the IP of the bastion node (running kubectl against primary and secondary K8s clusters) as well as ssh information for control plane operations and the ssh user and ssh key to access those nodes (need to be the same). |
| [maak8-etcd-backup.sh](./maak8-etcd-backup.sh) | This script creates a backup of a control plane inculding keys, control plane pods config (kubeadm) and creates an etcd snapshot of the primary cluster |
| [maak8-etcd-restore.sh](./maak8-etcd-restore.sh) | This script restores a backup from maak8backup.sh in another system this target system MUST USE THE SAME HOSTNAME ALIASES for control plane nodes and kube api access point |. 
| [maak8s-force-stop-cp.sh](./maak8s-force-stop-cp.sh) | This script forcefully stops the control plabe process in the different control plane nodes (list provided as command line argument) |. 

