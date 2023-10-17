DRS scripts  
Copyright (c) 2022 Oracle and/or its affiliates  
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/  

STEPS TO PREPARE THE ENVIRONMENT FOR DRS EXECUTION 
=====================================================

These steps describe how to configure the local runtime to run DRS. 
This must be done only in the host that runs the DRS. This is not needed to be performed in the rest of the hosts.
The unzipped folded of DRS will be referred as <DRS_HOME>. It contains a folder "_internal_python" that will be configured as the python virtual environment with the python libraries that are required to run DRS.   
The following steps explain how to configure that folder as the virtualenv for python and how to download the required libraries.

NOTE: Perform the steps with a user different than root. Recommended is to use the user opc.

NOTE: To run these steps, the host requires connectivity to Internet, to download the python packages required by DRS.

1- Verify that python3 is available in the system by executing the following:

	$ python3 -m pip --version

	Example:
	[opc@host]$ python3 -m pip --version
	pip 9.0.3 from /usr/lib/python3.6/site-packages (python 3.6)

2- The folder "_internal_python" under the extracted DRS will be used as the python virtual environment. 
Run the following to create a virtualenv in the folder
	
	$ python3 -m venv <DRS_HOME>/_internal_python

	Example:
	[opc@host]$ python3 -m venv /home/opc/drs_mp_soa/_internal_python

3- Activate the virtual environment

	$ cd <DRS_HOME>/_internal_python
	$   source ./bin/activate

You will see that the prompt changes.

	Example:
	[opc@host] $ cd <DRS_HOME>/_internal_python
	[opc@host]$ source ./bin/activate
	(pythonvenv) [opc@host _internal_python]$

4- Without existing the virtual env, upgrade the tools in the virtualenv with the following command

	python3 -m pip install --upgrade pip setuptools wheel

	Example:
	(pythonvenv) [opc@host _internal_python]$ python3 -m pip install --upgrade pip setuptools wheel

5- Install required libraries for running DRS in the virtual env  
a) Make sure the file requirements-drs-plain.txt is in the folder _internal_python   
b) Without existing the virtual env, run library installation with python3 -m pip install  

	(pythonvenv) [opc@host _internal_python]$ python3 -m pip install -r requirements-drs-plain.txt

Now the environment is prepared to run DRS. 
Continue with the README.md for specific instructions to run DRS.
