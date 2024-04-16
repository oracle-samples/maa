MAA WLS lifecycle scripts  
Copyright (c) 2023 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/

# MAA WebLogic Lifecycle Scripts

Scripts to individually stop and start WebLogic processes (Administration Server, Managed server and Node Manager) in **SOA Marketplace** and **WLS for OCI** compute instances.

## Scripts
| Script name  | Description |
| ------------- | ------------- |
| [wls_start.sh](./wls_start.sh) | This script is used to start WebLogic proceses in a midtier host.  |
| [wls_stop.sh](./wls_stop.sh) | This script is used to stop WebLogic proceses in a midtier host. |
| [start_servers.py](./start_servers.py) | _Referenced by other scripts_. Python script used by wls_start.sh |
| [stop_servers.py](./stop_servers.py) | _Referenced by other scripts_. Python script used by wls_stop.sh |
| [nmkill_servers.py](./nmkill_servers.py) | _Referenced by other scripts_. Python script used by wls_stop.sh |

## Setup
For each mid-tier compute instance:
- Copy the scripts to /opt/scripts/restart folder as user oracle.
- Create the encrypted credentials files for the WebLogic administration user. 
```
/u01/app/oracle/middleware/oracle_common/common/bin/wlst.sh
connect("weblogic","password","t3://<adminhost>:9071")
storeUserConfig() 
```
- Copy the generated files (oracle-WebLogicConfig.properties and oracle-WebLogicKey.properties) to the folder /opt/scripts/restart.


## Usage
### wls_start.sh
**Usage:**  wls_start.sh [nm/aserver/mserver/all]  
| option |  |
| ------ | ------ |
| nm |  starts the node manager in the host   |
| aserver  | if the host is the administration host, it starts the administration server (and node manager in case it is down) |
| mserver  | starts the managed server in the host (and node manager in case it is down) |
| all  | starts the node manager, the administration server, and the managed server in the host |


### wls_stop.sh
**Usage:**  wls_stop.sh [aserver/mserver/servers/nm/all]  
| option | header |
| ------ | ------ |
| aserver | if the host is the administration host, it stops the administration server in the host |
| mserver | stops the managed server in the host |
| servers | stops the administration (if the host is the administration host) and managed server in the host |
| nm | stops the node manager in the host |
| all | stop all (managed server, administration server and node manager) in the host |

### Examples
- Stop the Managed Server that runs in the host: `./wls_stop.sh mserver`
- Stop the Admin Server in the host: `./wls_stop.sh aserver`
- Stop the Node Manager in the host:  `./wls_stop.sh nm`
- Stop all the WebLogic servers that run in the host (NM is not stopped):  `./wls_stop.sh servers`
- Stop all the WebLogic processes that run in the host (including NM):  `./wls_stop.sh all`
- Start the Node Manager in the host:   `./wls_start.sh nm`
- Start the Admin Server in the Administration host: `./wls_start.sh aserver`
- Start the Managed Server that runs in the host:   `./wls_start.sh mserver`
- Start all the processes in the host:  `./wls_start.sh all`

## Dependencies
These scripts rely in functions and scripts available in the compute instances of **SOA Marketplace** and **WLS for OCI**. Hence, they are supported in these environments only.
