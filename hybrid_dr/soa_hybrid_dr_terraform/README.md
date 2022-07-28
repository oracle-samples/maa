SOA Hybrid dr terraform scripts v 1.0  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for SOA Hybrid DR

This project contains the following code to create resources as described in the playbook https://docs.oracle.com/en/solutions/soa-dr-on-cloud/index.html 

## HybridDR_NetworkResources 
Terraform code to create the VCN, the subnets and the network security rules as described in "Configure the Network" section.  

## HybridDR_DBSystem
Terraform code to create the DB System for the section "Configure Oracle Data Guard". 

## HybridDR_FSSresources
Terraform code to create the File System Service resources (mount targets, file systems, exports) as described in "Prepare the Storage on OCI" section. 

## HybridDR_SOAComputeInstances
Terraform code to create the OCI compute instances for the midtier nodes, as described in "Provision the Compute Instances for the SOA Mid-tier Nodes" section.   

## HybridDR_OCILoadBalancer
Terraform code to create the OCI Load Balancer and its configuration as described in "Prepare the Web-tier on OCI" section.  


# Recommended order to use them is: 
1) HybridDR_NetworkResources, to create the network resources.
2) HybridDR_DBSystem, to create the DB system.
3) HybridDR_FSSresources, to create the FSS resources.
4) HybridDR_SOAComputeInstances to create the midtier nodes
5) HybridDR_OCILoadBalancer, to create the OCI Load Balancer (which requires the midtier nodes).

Note: the order of 2,3,4 does not matter.

# Usage
In each case, provide your environment values in the terraform.tfvars file. 
Then run "terraform plan" and "terraform apply" to create the resources.


