SOA Hybrid dr terraform scripts v 1.0  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for creating network resources for SOA Hybrid DR
---------------------------------------------------------------
This terraform code is referenced in the section "Prepare the Storage on OCI" 
of the playbook "Configure a hybrid DR solution for Oracle SOA Suite" 
Reference: https://docs.oracle.com/en/solutions/soa-dr-on-cloud 
 
This terraform code will create: 
- 1 mount target (if only 1 AD is used) or 2 mount targets (if 2 ADs are used). 
- 4 File Systems 
	- 1 file system for the shared config 
	- 1 file system for the shared runtime 
	- 1 for products1  (private file system for soa node1) 
	- 1 for products2  (private file system for soa node2). If there are 2 ADs, this will be created in the second AD. 
- 4 exports, one per each file system, in the appropriate AD. 
 
The names of the file systems and the export paths are configurable in terraform.tfvars file. 
 
Steps to use: 
- Edit terraform.tfvars file. 
- Provide the customer values. 
- Run "terraform plan" to review the resources that are going to be created. 
- Run "terraform apply" to create the resources. 
