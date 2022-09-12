WLS Hybrid DR terraform scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

# Terraform code for creating OCI LBR for Hybrid DR
---------------------------------------------------------------
This terraform code is referenced in the section "Prepare the Web-tier on OCI" of the playbooks:  
"Configure a hybrid DR solution for Oracle SOA Suite" https://docs.oracle.com/en/solutions/soa-dr-on-cloud  
"Configure a hybrid DR solution for WebLogic" https://docs.oracle.com/en/solutions/weblogic-server-dr-on-cloud  
 
This terraform code will create the components and configurations described in the  Hybrid DR document:
- A new OCI Load Balancer in the web-tier subnet. 
- The backendsets and backends:
	- If OHS is used:
		- OHS_Admin_backendset: 
			- with one backend per OHS node (ohs1_IP:ohs_httpconsoles_port, ohs2_IP:ohs_httpconsoles_port, etc.)
		- OHS_HTTP_backendset:  
			- with one backend per OHS node (ohs1_IP:ohs_http_port, ohs2_IP:ohs_http_port, etc.)
		- (optional) OHS_HTTP_internal_backendset: 
			- with one backend per OHS node (ohs1_IP:ohs_httpinternal_port, ohs2_IP:ohs_httpinternal_port, etc.)

	- IF OHS is not used:
		- Admin_backendset: 
			- with one backend only, the Administration server (admin_vip:adminserver_port)
		- N cluster backendsets: 
			- one backendset per WLS cluster, as provided in the clusters.yamls file. Each backendset contains one backend per WLS server in the cluster.

	- Either OHS is used or not:
		- empty_backendset : empty backend set for the  HTTP_listener, because this listener just redirects all to HTTPS.

- The routing policies with the appropriate rules: 
	- Admin_rules routing policy : 
		- with the Admin_routerule. To route /console and /em to the appropriate admin backend set.
	- Application_rules routing policy: 
		- with N <cluster_name>_routerule. To route the application requests to the appropriate backendset.
	- (optional) Internal_rules : 
		- with N <cluster_name>_routerule. To route internal applications requests to the appropriate internal backend set. 
		- this applies to the clusters marked as internal in the clusters.yaml file. (E.g. OWSM in SOA)

- The frontend hostnames that are used by the listeners, as provided in the input parameters. 

- The SSL certificate used by the HTTPS listener.

- The listeners: 
	- Admin_listener:     this is to access to the WebLogic Consoles
	- HTTPS_listener:     this is the main listener to access to applications, in HTTPS
	- HTTP_listener :     this only redirects all requests to HTTPS_listener
	- (optional) HTTP_internal_listener:    this is optional. Not secure, used only for internal accesses if needed. (E.g. OWSM in SOA)

- The required rulesets for SSL: 
	- HTTP_to_HTTPS_redirect:    for the HTTP_listener 
	- SSLHeaders:     for the HTTPS_listener 

 

Steps to use: 
- Edit terraform.tfvars file and provide your environment values.
- Edit the clusters.yaml and provide your environment values. This is required regardless you use OHS or not.
- Run "terraform plan" to review the resources that are going to be created. 
- Run "terraform apply" to create the resources. 
