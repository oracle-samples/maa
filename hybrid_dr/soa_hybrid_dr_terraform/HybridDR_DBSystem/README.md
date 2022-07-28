SOA Hybrid dr terraform scripts v 1.0  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for creating OCI DB System for SOA Hybrid DR
----------------------------------------------------------------------
This terraform code is referenced in the section "Configure Oracle Data Guard" 
of the playbook "Configure a hybrid DR solution for Oracle SOA Suite" 
Reference: https://docs.oracle.com/en/solutions/soa-dr-on-cloud 
 
This terraform code will create: 
- A DB System based on the input attributes specified by customer 

Steps to use: 
- Terraform code in folder "1_get_shapes_and_versions" can be used to get the list of shapes and versions available. 
	- Edit terraform.tfvars file. 
	- Provide the customer values. 
	- Run "terraform plan" to get the info. 
	- Choose the shape and version that match to the values  used by the on-premises database. 

- Terraform code in folder "2_create_DBSystem" is used to provision the DB System with the values provided. 
	- Edit terraform.tfvars file. 
	- Provide the customer values. 
	- Run "terraform plan" to review the resources that are going to be created. 
	- Run "terraform apply" to create the resources. 
