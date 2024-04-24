MAA WLS lifecycle scripts  
Copyright (c) 2024 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

# MAA WebLogic Lifecycle Scripts

Scripts to individually stop and start WebLogic processes (Administration Server, Managed server and Node Manager) in EDG or generic domains.
> For SOA Marketplace and WLS for OCI domains, use simplified scripts in [PaaS](../PaaS).

## Scripts
| Script name  | Description |
| ------------- | ------------- |
| [wls_start.sh](./wls_start.sh) | Script to start WebLogic proceses in a midtier host (node manager, Administration server, or managed servers).  |
| [wls_stop.sh](./wls_stop.sh) | Script to stop WebLogic proceses in a midtier host (node manager, Administration server, or managed servers). |
| [/py_scripts](./py_scripts) | This folder contains python scripts and utilities invoked by wls_start.sh and wls_stop-sh scripts. |
| [domain_properties.env](./domain_properties.env) | Environment file to provide WebLogic domain information. |

## Setup
For each mid-tier compute instance:
- Copy the items to a folder as user oracle. This folder is referenced as <SCRIPTS_FOLDER>
- Create the encrypted credentials files for the WebLogic administration user. 
```
<MW_HOME>/oracle_common/common/bin/wlst.sh
connect("weblogic","password","t3(s)://<adminhost>:<adminhost_port>")
storeUserConfig() 
```
- Copy the generated files (e.g. oracle-WebLogicConfig.properties and oracle-WebLogicKey.properties) to a folder. For example, <SCRIPTS_FOLDER>
- Edit the file domain_properties.env and provide the information.


## Usage
### wls_start.sh
**Usage:**  wls_start.sh [nm/aserver/mserver/cluster] [server_name/cluster_name]
| option |  |
| ------ | ------ |
| nm |  starts the node manager in the host   |
| aserver  | it starts the Admin Server (and Node Manager in case it is down). It must run in the admin host. |
| mserver  | it starts the managed server in the host (and node manager in case it is down). The name of the managed server must be passed as input. |
| cluster  | it connects to Admin Server to remotely start all the managed servers of the provided cluster name. Node manager must be already up in the hosts. |
| server_name | the name of the managed server that you want to start when using 'mserver' option |
| cluster_name | the name of the WebLogic Cluster that you want to start when using 'cluster' option |



### wls_stop.sh
**Usage:**  wls_stop.sh [aserver/mserver/nm/cluster] [server_name/cluster_name]
| option | header |
| ------ | ------ |
| aserver | it stops the Admin server in this host. It must run in the admin host.  |
| mserver | it stops the managed server in the host. The name of the managed server must be passed as input. |
| nm | it stops the node manager in the host. |
| cluster | it connects to Admin Server to remotely stop all the managed servers of the provided cluster name. Node manager must be already up in the hosts. |
| server_name | the name of the managed server that you want to start when using 'mserver' option |
| cluster_name | the name of the WebLogic Cluster that you want to start when using 'cluster' option |

## Examples
- Stop a cluster   `./wls_stop.sh cluster SOA_Cluster`
- Stop a Managed Server  `./wls_stop.sh mserver WLS_WSM1`
- Stop the Admin Server `./wls_stop.sh aserver`
- Stop the Node Manager   `./wls_stop.sh nm`
- Start the Node Manager   `./wls_start.sh nm`
- Start the Admin Server `./wls_start.sh aserver`
- Start a Managed Server   `./wls_start.sh mserver WLS_WSM1`
- Start a cluster   `./wls_start.sh cluster SOA_Cluster`
