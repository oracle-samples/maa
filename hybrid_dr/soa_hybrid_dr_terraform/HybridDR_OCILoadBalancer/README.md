SOA Hybrid dr terraform scripts v 1.0  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for creating OCI LBR for SOA Hybrid DR
---------------------------------------------------------------
This terraform code is referenced in the section "Prepare the Web-tier on OCI" 
of the playbook "Configure a hybrid DR solution for Oracle SOA Suite" 
Reference: https://docs.oracle.com/en/solutions/soa-dr-on-cloud 
 
This terraform code will create: 
- A new OCI Load Balancer in the web-tier subnet. 
- The components and configurations described in the SOA Hybrid DR document: 
	- The backendsets and backends 
		- Admin_backendset: admin_vip:adminserver_port 
		- WSM_backendset: midtier1_IP:wsm_port, midtier2_IP:wsm_port, etc. 
		- SOA_backendset: midtier1_IP:soa_port, midtier2_IP:soa_port, etc. 
		- OSB_backendset: midtier1_IP:osb_port, midtier2_IP:osb_port, etc. 
		- ESS_backendset: midtier1_IP:ess_port, midtier2_IP:ess_port, etc.  
		- BAM_backendset: midtier1_IP:bam_port, midtier2_IP:bam_port, etc. 
		(if additional midtier IPs are provided, the backendsets will add them too) 
	- The routing policies that are used by the listeners, with the appropriate rules: 
		- Admin_rules : Admin_routerule 
		- Internal_Rules: WMS_routerule 
		- SOA_Rules: SOA_routerule, ESS_routerule, BAM_routerule, B2B_routerule, OSB_routerule 
	- The hostnames that are used by the listeners 
	- The SSL certificate used by the HTTPS listener
	- The listeners: 
		- Admin_listener 
		- Internal_listener 
		- SOA_listener (HTTPS) 
		- HTTP_listener 
	- The required rulesets: 
		- HTTP_to_HTTPS_redirect - for the HTTP_listener 
		- SSLHeaders - for the SOA_listener 
 
Steps to use: 
- Edit terraform.tfvars file. 
- Provide the customer values. 
- Run "terraform plan" to review the resources that are going to be created. 
- Run "terraform apply" to create the resources. 
