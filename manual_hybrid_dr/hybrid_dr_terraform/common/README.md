WLS Hybrid DR terraform scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

## HybridDR_NetworkResources 
Terraform code to create the VCN, the subnets and the network security rules as described in "Configure the Network" section.  

## HybridDR_DBSystem
Terraform code to create the DB System for the section "Configure Oracle Data Guard". 

## HybridDR_FSSresources
Terraform code to create the OCI File System resources (mount targets, file systems, exports) as described in "Prepare the Storage on OCI" section. 

## HybridDR_OCILoadBalancer
Terraform code to create the OCI Load Balancer and its configuration as described in "Prepare the Web-tier on OCI" section.  

# Usage
In each case, provide your environment values in the terraform.tfvars file. 
Then run "terraform plan" and "terraform apply" to create the resources.
