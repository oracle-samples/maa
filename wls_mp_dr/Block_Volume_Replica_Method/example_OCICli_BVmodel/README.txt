## ExampleBVReplicaOCICli
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##


STEPS TO USE THIS EXAMPLE FOR SWITCHOVER

-------------------------------------------------------------------------------------------------------
NOTE: Only some steps of the switchover are automated by this example.
The rest of the steps must be performed manually.
The switchover and post-switchover scripts provide some guide about the steps that must be run manually.
-------------------------------------------------------------------------------------------------------


Preparation
------------------
1.- Make sure the OCI CLI is already installed and configured in the host running this example
2.- Edit the file DRenv.properties and complete with your environment information


Run a switchover
------------------
1.- Run the scripts for the switchover
./SWITCHOVER.sh <from_region> <to_region>
Example:  
To switchover from Ashburn to Phoenix:
./SWITCHOVER.sh us-ashburn-1 us-phoenix-1 
<then perform pending manual steps>

2.- Once switchover is complete, run the script for post-steps
./POST_SWITCHOVER.sh <from_region> <to_region>
Note that the order of the regions is important. It must be the same than the order used when running the SWITCHOVER.sh script.
Example:  
To run the post steps after a switchover from Ashburn to Phoenix:
./POST_SWITCHOVER.sh us-ashburn-1 us-phoenix-1
<then perform pending manual post steps>


Run a switchback
------------------
The switchback is like the switchover, but in the other way
For example, to switchback from Phoenix to Ashburn:
./SWITCHOVER.sh us-phoenix-1 us-ashburn-1
<perform manual steps>
./POST_SWITCHOVER.sh us-phoenix-1 us-ashburn-1
<perform manual post steps>



