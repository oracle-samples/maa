import oci
import re
import ipaddress

class OciManager:
    weblogic_image = "Oracle WebLogic Suite UCM Image"
    ohs_image = "Oracle WebLogic Server Enterprise Edition UCM Image"
    shape_name = "VM.Standard.E3.Flex"


    def __init__(self, compartment, config_path=None):
        """Constructor

        Args:
            compartment (str): OCID of compartment where this instance of 
                    OciManager will create resources
            config_path (filepath, optional): Path of oci config file. 
                    Defaults to None in which case the oci sdk default of 
                    /home/<user>/.oci/config will be used

        Raises:
            ValueError: If compartment ID is not a valid OCID
            RuntimeError: If querying OCI for available Availability 
                    Domains returned nothing
        """
        if config_path is None:
            self.config = oci.config.from_file()
        else:
            self.config = oci.config.from_file(config_path)
        if not self._is_valid_ocid(compartment):
            raise ValueError(f"Compartment ID {compartment} is not a valid OCID")
        self.compartment = compartment
        self.identity_client = oci.identity.IdentityClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.compute_client = oci.core.ComputeClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.virtual_network_client = oci.core.VirtualNetworkClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.block_volume_client = oci.core.BlockstorageClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.file_storage_client = oci.file_storage.FileStorageClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.marketplace_client = oci.marketplace.MarketplaceClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.dns_client = oci.dns.DnsClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        self.lbr_client = oci.load_balancer.LoadBalancerClient(self.config, retry_strategy=oci.retry.DEFAULT_RETRY_STRATEGY)
        success, ret = self.get_availability_domains()
        if not success:
            raise RuntimeError(f"Cannot retrieve availability domains: {ret}")
        self.availability_domains = ret

    def _is_valid_ocid(self, ocid):
        """Checks if given OCID is valid

        Args:
            ocid (str): OCID to validate

        Returns:
            Bool: True if given OCID follows expected format as per
            https://docs.oracle.com/en-us/iaas/Content/General/Concepts/identifiers.htm#ariaid-title2,
            otherwise False
        """
        pattern = r'^([0-9a-zA-Z-_]+[.:])([0-9a-zA-Z-_]*[.:]){3,}([0-9a-zA-Z-_]+)$'
        if re.match(pattern, ocid):
            return True
        return False
    
    def _is_valid_name(self, name):
        """Checks if given resource name is valid:
            - must only consist of alphanum, '-' and '_'

        Args:
            name (str): Resource name to check

        Returns:
            Bool: True if valid name, else False
        """
        pattern = r'^[a-zA-Z0-9-_]*$'
        if re.match(pattern, name):
            return True
        return False
    
    def _is_valid_path(self, path):
        """Checks if given path is valid:
            - must begin with '/'
            - must only consist of alphanum, '/', '-', '_' and '.'
            - no successive '/' allowed
            - must not end in '/'

        Args:
            path (str): Path to check

        Returns:
            Bool: True if valid path, else False
        """
        if not isinstance(path, str):
            return False
        if path[0] != "/":
            return False
        if any(sbstr == "" for sbstr in path.split("/")[1:]):
            return False
        pattern = r'^[a-zA-Z0-9-_/.]*$'
        if re.match(pattern, path):
            return True
        return False
    
    def _is_valid_description(self, description):
        """Checks if given description is valid:
            - maximum 255 characters

        Args:
            description (str): Description to check

        Returns:
            Bool: True if valid description, else False
        """
        if not isinstance(description, str):
            return False
        if len(description) > 255:
            return False
        return True
    
    def _is_valid_os_version(self, os_version):
        """Checks if given os version is valid
            - must be castable to float

        Args:
            os_version (str): Os version to check

        Returns:
            Bool: True if valid os version, else False
        """
        try:
            _ = float(os_version)
        except ValueError:
            return False
        return True
        
    def _is_valid_domain(self, domain):
        """Checks if given domain name is valid:
            - must be between 1 and 63 chars long
            - must not start or end with '-'
            - must only consist of alphanum and '-'

        Args:
            domain (str): Domain name to check

        Returns:
            Bool: True if domain valid, else False
        """
        if domain[0] == '-' or domain[-1] == '-':
            return False
        pattern = r'^[a-zA-Z0-9-]{1,63}$'
        if re.match(pattern, domain):
            return True
        return False
    
    def _is_valid_zone_name(self, zone_name):
        """Checks if given zone name is valid:
            - must consist of minimum 2 valid dot seperated domains 
            - no sequential dots
            - must not start or end with '.' or '-'

        Args:
            zone_name (str): Zone name to check

        Returns:
            Bool: True if valid zone name, else False
        """
        doms = zone_name.split(".")
        if any(len(dom) == 0 for dom in doms):
            return False
        if len(doms) < 2:
            return False
        return all(self._is_valid_domain(dom) for dom in doms)
    
    def _is_valid_record_name(self, record_name):
        """Checks if given record name is valid:
            - must consist of 1 or more valid dot seperated domains 
            - no sequential dots
            - must not start or end with '.' or '-'

        Args:
            zone_name (str): Record name to check

        Returns:
            Bool: True if valid record name, else False
        """
        doms = record_name.split(".")
        if any(len(dom) == 0 for dom in doms):
            return False
        return all(self._is_valid_domain(dom) for dom in doms)
        
    def _is_valid_ip(self, ip):
        """Checks if given IP is valid

        Args:
            ip (str): IP to check

        Returns:
            Bool: True if IP is valid, else False
        """
        try:
            _ = ipaddress.ip_address(ip)
            return True
        except ValueError:
            return False
        
    def _is_valid_cidr(self, cidr_block):
        """Checks if given CIDR block is valid

        Args:
            cidr_block (str): CIDR block to check

        Returns:
            Bool: True if CIDR block is valid, else False
        """
        try:
            octs, bit = cidr_block.split("/")
            bit = int(bit)
        except (AttributeError, ValueError):
            return False
        if 0 > bit or 31 <= bit:
            return False
        return self._is_valid_ip(octs)
    
    def _is_valid_port(self, port):
        """Checks if given port is valid:
            - must be of type int or str
            - must be between 1 and 65535

        Args:
            port (str|int): Port to check

        Returns:
            Bool: True if port is valid, else False
        """
        if type(port) not in [str, int]:
            return False
        try:
            if int(port) < 1 or int(port) > 65535:
                return False 
        except ValueError:
            return False
        return True

    def get_availability_domains(self):
        """Queries OCI for availability domains

        Returns:
            - (True, list[str]): Touple consisting of bool True and list of 
                    availability domains
            - (False, str): If query failed - touple consisting of bool False 
                    and exception encountered
        """
        try:
            ads_resp = self.identity_client.list_availability_domains(self.compartment)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, [ad.name for ad in ads_resp.data]

    def get_vcns(self):
        """Queries OCI for VCNs

        Returns:
            - (True, list[oci.core.models.Vcn]): Touple consisting of bool True and 
                    list of oci.core.models.Vcn objects of found VCNs
            - (False, str): If query failed - touple consisting of bool False and 
                    exception encountered
            - (True, None): If query succeeded, but no VCNs found - touple consisting of
                    bool True and None object
        """
        try:
            vcns = self.virtual_network_client.list_vcns(self.compartment)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if len(vcns.data):
            return True, vcns.data
        return True, None
    
    def get_vcn_by_name(self, vcn_name):
        """Queries OCI for a VCN with a given name

        Args:
            vcn_name (str): Name of VCN to query for

        Returns:
            - (True, oci.core.models.Vcn): Touple consisting of bool True and 
                     oci.core.models.Vcn object of found VCN
            - (False, str): If query failed - touple consisting of bool False and 
                    exception encountered
            - (True, None): If query succeeded, but no VCN found with given name - touple 
                    consisting of bool True and None object
        """
        if not self._is_valid_name(vcn_name):
            return False, f"VCN name {vcn_name} is invalid"
        
        success, ret = self.get_vcns()
        if not success:
            return False, ret
        for vcn in ret:
            if vcn.display_name == vcn_name:
                return True, vcn
        return True, None
    
    def get_vcn_by_id(self, vcn_id):
        """Queries OCI for a VCN with a given OCID

        Args:
            vcn_id (str): OCID of VCN to query for

        Returns:
            - (True, oci.core.models.Vcn): Touple consisting of bool True and 
                     oci.core.models.Vcn object of found VCN
            - (False, str): If query failed - touple consisting of bool False and 
                    exception encountered
            - (True, None): If query succeeded, but no VCN found with given OCID - touple 
                    consisting of bool True and None object
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        
        success, ret = self.get_vcns()
        if not success:
            return False, ret
        for vcn in ret:
            if vcn.id == vcn_id:
                return True, vcn
        return True, None

    def create_vcn(self, vcn_name, cidr_blocks):
        """Created a new VCN

        Args:
            vcn_name (str): Name to assign to VCN
            cidr_blocks (list[str]): List of CIDR blocks to assign to VCN    

        Returns:
            - (True, oci.core.models.Vcn): Touple consisting of bool True and 
                     oci.core.models.Vcn object of newly created VCN
            - (False, str): If creation failed - touple consisting of bool False and 
                    exception encountered
        """
        if not self._is_valid_name(vcn_name):
            return False, f"VCN name {vcn_name} is invalid"
        if not isinstance(cidr_blocks, list):
            return False, "cidr_blocks must be a list of CIDR blocks"
        for block in cidr_blocks:
            if not self._is_valid_cidr(block):
                return False, f"CIDR block {block} is invalid"
        
        dns_label = ""
        count = 1
        for char in vcn_name:
            if count > 15:
                break
            if char.isalnum():
                dns_label += char
                count += 1
        vcn_model = oci.core.models.CreateVcnDetails(
            compartment_id=self.compartment,
            display_name=vcn_name,
            dns_label=dns_label,
            cidr_blocks=cidr_blocks
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            new_vcn_resp = composite_operation.create_vcn_and_wait_for_state(
                create_vcn_details=vcn_model,
                wait_for_states=[oci.core.models.Vcn.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, new_vcn_resp.data
    
    def get_subnets(self, vcn_id):
        """Queries OCI for all subnets in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to query

        Returns:
            - (True, list[oci.core.models.Subnet]): Touple consisting of bool True and 
                        list of all oci.core.models.Subnet objects found in given VCN
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query succeeded, 
                        but no subnets found in VCN 
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        
        try:
            subnets_result = self.virtual_network_client.list_subnets(
                compartment_id=self.compartment,
                vcn_id=vcn_id
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if len(subnets_result.data) > 0:
            return True, subnets_result.data
        return True, None
    
    def get_subnet_by_name(self, vcn_id, subnet_name):
        """Queries OCI for a given subnet in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to query
            subnet_name (str): Name of subnet to query for

        Returns:
            - (True, oci.core.models.Subnet): Touple consisting of bool True and 
                        oci.core.models.Subnet object of found subnet
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query succeeded, 
                        but given subnet not found in VCN 
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(subnet_name):
            return False, f"Subnet name {subnet_name} is invalid"
        
        success, ret = self.get_subnets(vcn_id)
        if not success:
            return False, ret
        if ret is None:
            return True, None
        for subnet in ret:
            if subnet.display_name == subnet_name:
                return True, subnet
        return True, None
    
    def get_subnet_by_id(self, vcn_id, subnet_id):
        """Queries OCI for a subnet with a given OCID

        Args:
            vcn_id (str): VCN OCID where to query for subnet
            subnet_id (str): Subnet OCID to query for

        Returns:
            - oci.core.models.Subnet: oci.core.models.Subnet object with subnet details if found
            - None: if no subnet with given ID found in given VCN
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_ocid(subnet_id):
            return False, f"Subnet ID {subnet_id} is not a valid OCID"
        
        success, ret = self.get_subnets(vcn_id)
        if not success:
            return False, ret
        if ret is None:
            return None
        for subnet in ret:
            if subnet.id == subnet_id:
                return subnet
        return None
    
    def add_sec_list_subnet(self, vcn_id, subnet_id, security_list_id):
        """Adds a given security list to a subnet

        Args:
            vcn_id (str): VCN OCID of subnet
            subnet_id (str): OCID of subnet to update
            security_list_id (str): OCID of security list to add to subnet

        Returns:
            - (True, oci.core.models.Subnet): Touple consisting of bool True and 
                        oci.core.models.Subnet object of updated subnet
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_ocid(subnet_id):
            return False, f"Subnet ID {subnet_id} is not a valid OCID"
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        
        subnet = self.get_subnet_by_id(vcn_id, subnet_id)
        if subnet is None:
            return False, f"No subnet with OCID {subnet_id} found"
        sec_list_ids = subnet.security_list_ids
        sec_list_ids.append(security_list_id)
        update_model = oci.core.models.UpdateSubnetDetails(security_list_ids=sec_list_ids)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_resp = composite_operation.update_subnet_and_wait_for_state(
                subnet_id=subnet_id,
                update_subnet_details=update_model,
                wait_for_states=[oci.core.models.Subnet.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_resp.data
    
    def get_internet_gateway(self, vcn_id):
        """Queries OCI for Internet Gateway in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to query

        Returns:
            - (True, oci.core.models.InternetGateway): Touple consisting of bool True and 
                        oci.core.models.InternetGateway object of found Internet Gateway
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query succeeded, 
                        but no Internet Gateway found in VCN 
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        
        try:
            ig_resp = self.virtual_network_client.list_internet_gateways(
                compartment_id=self.compartment, 
                vcn_id=vcn_id
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if ig_resp.data:
            return True, ig_resp.data[0]
        return True, None
    
    def create_internet_gateway(self, vcn_id, internet_gateway_name):
        """Creates an Internet Gateway in given VCN

        Args:
            vcn_id (str): OCID of VCN in which to create the Internet Gateway
            internet_gateway_name (str): Name to assign to Internet Gateway

        Returns:
            - (True, oci.core.models.InternetGateway): Touple consisting of bool True and 
                        oci.core.models.InternetGateway object of newly created Internet Gateway
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(internet_gateway_name):
            return False, f"Internet Gateway name {internet_gateway_name} is not valid"      
              
        ig_details = oci.core.models.CreateInternetGatewayDetails(
            display_name=internet_gateway_name,
            compartment_id=self.compartment,
            is_enabled=True,
            vcn_id=vcn_id
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            create_ig_resp = composite_operation.create_internet_gateway_and_wait_for_state(
                ig_details,
                wait_for_states=[oci.core.models.InternetGateway.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_ig_resp.data
        
    def add_ig_to_route_table(self, vcn_route_table_id, internet_gateway_id):
        """Adds Internet Gateway to a given route table

        Args:
            vcn_route_table_id (str): OCID of Route Table to add Internet Gateway
            internet_gateway_id (str): OCID of Internet Gateway to add

        Returns:
            - (True, oci.core.models.InternetGateway): Touple consisting of bool True and 
                        oci.core.models.RouteTable object of updated route table
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_route_table_id):
            return False, f"VCN Route Table ID {vcn_route_table_id} is not a valid OCID"
        if not self._is_valid_ocid(internet_gateway_id):
            return False, f"Internet Gateway ID {internet_gateway_id} is not a valid OCID"
        
        success, ret = self.get_route_table(vcn_route_table_id)
        if not success:
            return False, ret
        rules = ret.route_rules
        new_rule = oci.core.models.RouteRule(
            cidr_block=None,
            destination='0.0.0.0/0',
            destination_type='CIDR_BLOCK',
            network_entity_id=internet_gateway_id
        )
        rules.append(new_rule)
        update_table_details = oci.core.models.UpdateRouteTableDetails(route_rules=rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_route_table_resp = composite_operation.update_route_table_and_wait_for_state(
                vcn_route_table_id,
                update_table_details,
                wait_for_states=[oci.core.models.RouteTable.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_route_table_resp.data

    def get_service_gateway(self, vcn_id):
        """Queries OCI for Service Gateway in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to query

        Returns:
            - (True, oci.core.models.ServiceGateway): Touple consisting of bool True and 
                        oci.core.models.ServiceGateway object of found Service Gateway
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query succeeded, 
                        but no Service Gateway found in VCN 
        """        
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        
        try:
            service_gw_resp = self.virtual_network_client.list_service_gateways(
                compartment_id=self.compartment,
                vcn_id=vcn_id
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if service_gw_resp.data:
            return True, service_gw_resp.data[0]
        return True, None

    def get_osn_details(self, osn_service_id):
        """Queries OCI for OSN service details

        Args:
            osn_service_id (str): OCID of OSN service

        Returns:
            - (True, oci.core.models.Service): Touple consisting of bool True and 
                        oci.core.models.Service object of OSN service ID
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query succeeded, 
                        but no Service Gateway found in VCN 
        """        
        if not self._is_valid_ocid(osn_service_id):
            return False, f"OSN service ID {osn_service_id} is not a valid OCID"
        
        try:
            service_gw_resp = self.virtual_network_client.get_service(service_id=osn_service_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if service_gw_resp.data:
            return True, service_gw_resp.data
        return True, None

    def create_service_gateway(self, vcn_id, service_gw_name):
        """Creates an Oracle Services gateway in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to create the service gateway
            service_gw_name (str): Name to assign to service gateway

        Returns:
            - (True, oci.core.models.ServiceGateway): Touple consisting of bool True and 
                        oci.core.models.ServiceGateway object of newly created Service Gateway
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(service_gw_name):
            return False, f"Service Gateway name {service_gw_name} is not valid"
        
        try:
            services = self.virtual_network_client.list_services()
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        for svc in services.data:
            if re.match("all.*services in oracle services network", svc.name.lower()):
                service = svc
        if not service:
            return False, "Could not retrieve service ID"
        serviceid_request_model = oci.core.models.ServiceIdRequestDetails(service_id=service.id)
        create_service_gw_model = oci.core.models.CreateServiceGatewayDetails(
            compartment_id=self.compartment,
            display_name=service_gw_name, 
            services=[serviceid_request_model], 
            vcn_id=vcn_id
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            create_resp = composite_operation.create_service_gateway_and_wait_for_state(
                create_service_gateway_details=create_service_gw_model, 
                wait_for_states=[oci.core.models.ServiceGateway.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_resp.data

    def get_nat_gateway(self, vcn_id):
        """Queries OCI for NAT gateway in given VCN

        Args:
            vcn_id (str): OCID of VCN in which to query

        Returns:
            - (True, oci.core.models.NatGateway): Touple consisting of bool True and 
                        oci.core.models.NatGateway object of found NAT Gateway
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query 
                        succeeded, but no NAT Gateway found in VCN 
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        try:
            nat_gw = self.virtual_network_client.list_nat_gateways(
                compartment_id=self.compartment,
                vcn_id=vcn_id
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if nat_gw.data:
            return True, nat_gw.data[0]
        return True, None

    def create_nat_gateway(self, vcn_id, nat_gw_name):
        """Creates a NAT Gateway in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to create the NAT Gateway
            nat_gw_name (str): Name to assign to new NAT Gateway

        Returns:
            - (True, oci.core.models.NatGateway): Touple consisting of bool True and 
                        oci.core.models.NatGateway object of newly created NAT Gateway
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(nat_gw_name):
            return False, f"NAT Gateway name {nat_gw_name} is not valid"

        nat_gw_model = oci.core.models.CreateNatGatewayDetails(
            compartment_id=self.compartment, 
            display_name=nat_gw_name, 
            vcn_id=vcn_id
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            create_resp = composite_operation.create_nat_gateway_and_wait_for_state(
                create_nat_gateway_details=nat_gw_model,
                wait_for_states=[oci.core.models.NatGateway.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_resp.data

    def get_route_table(self, route_table_id):
        """Queries OCI for a given Route Table

        Args:
            route_table_id (str): OCID of Route Table to query for

        Returns:
            - (True, oci.core.models.RouteTable): Touple consisting of bool True and 
                        oci.core.models.RouteTable object of found route table
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(route_table_id):
            return False, f"Route Table ID {route_table_id} is not a valid OCID"
        
        try:
            route_table_resp = self.virtual_network_client.get_route_table(route_table_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, route_table_resp.data
    

    def create_private_route_table(self, vcn_id, route_table_name, service_gateway_id, nat_gateway_id):
        """Creates a route table to be used with private subnets:
            - a route rule to Service Gateway (for all region services)
            - default route rule to NAT Gateway

        Args:
            vcn_id (str): OCID of VCN in which to create the route table
            route_table_name (str): Name to assign to route table
            service_gateway_id (str): OCID of Service Gateway to be used
            nat_gateway_id (str): OCID of NAT Gateway to be used

        Returns:
            - (True, oci.core.models.RouteTable): Touple consisting of bool True and 
                        oci.core.models.RouteTable object of newly created route table
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(route_table_name):
            return False, f"Route Table name {route_table_name} is not a valid name"
        if not self._is_valid_ocid(service_gateway_id):
            return False, f"Service Gateway ID {service_gateway_id} is not a valid OCID"
        if not self._is_valid_ocid(nat_gateway_id):
            return False, f"NAT Gateway ID {nat_gateway_id} is not a valid OCID"

        try:
            service_gateway = self.virtual_network_client.get_service_gateway(service_gateway_id=service_gateway_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        service_id = service_gateway.data.services[0].service_id
        try:
            service = self.virtual_network_client.get_service(service_id=service_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        service_cidr = service.data.cidr_block
        rules = []
        service_rule_model = oci.core.models.RouteRule(
            network_entity_id=service_gateway_id, 
            destination_type=oci.core.models.RouteRule.DESTINATION_TYPE_SERVICE_CIDR_BLOCK, 
            destination=service_cidr
        )
        rules.append(service_rule_model)
        nat_rule_model = oci.core.models.RouteRule(
            network_entity_id=nat_gateway_id,
            destination_type=oci.core.models.RouteRule.DESTINATION_TYPE_CIDR_BLOCK, 
            destination='0.0.0.0/0'
        )
        rules.append(nat_rule_model)
        create_table_model = oci.core.models.CreateRouteTableDetails(
            compartment_id=self.compartment, 
            vcn_id=vcn_id, 
            display_name=route_table_name,
            route_rules=rules
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            resp = composite_operation.create_route_table_and_wait_for_state(
                        create_route_table_details=create_table_model,
                        wait_for_states=[oci.core.models.RouteTable.LIFECYCLE_STATE_AVAILABLE]
                    )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, resp.data

    def create_public_route_table(self, vcn_id, route_table_name, internet_gateway_id):
        """Creates a route table to be used with public subnets:
            - default route rule to Internet Gateway

        Args:
            vcn_id (str): OCID of VCN in which to create the route table
            route_table_name (str): Name to assign to route table
            internet_gateway_id (str): OCID of Internet Gateway to be used

        Returns:
            - (True, oci.core.models.RouteTable): Touple consisting of bool True and 
                        oci.core.models.RouteTable object of newly created route table
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(route_table_name):
            return False, f"Route Table name {route_table_name} is not a valid name"
        if not self._is_valid_ocid(internet_gateway_id):
            return False, f"Internet Gateway ID {internet_gateway_id} is not a valid OCID"
        
        ig_rule_model = oci.core.models.RouteRule(
            network_entity_id=internet_gateway_id,
            destination_type=oci.core.models.RouteRule.DESTINATION_TYPE_CIDR_BLOCK, 
            destination='0.0.0.0/0'
        )
        create_table_model = oci.core.models.CreateRouteTableDetails(
            compartment_id=self.compartment, 
            vcn_id=vcn_id, 
            display_name=route_table_name,
            route_rules=[ig_rule_model]
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            resp = composite_operation.create_route_table_and_wait_for_state(
                        create_route_table_details=create_table_model,
                        wait_for_states=[oci.core.models.RouteTable.LIFECYCLE_STATE_AVAILABLE]
                    )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, resp.data

        

    def create_security_list(self, vcn_id, display_name):
        """Creates a security list

        Args:
            vcn_id (str): OCID of VCN in which to create security list
            display_name (str): Name to assign to security list

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of newly created security list
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_name(display_name):
            return False, f"Security list name {display_name} is not valid"
        
        sec_list_model = oci.core.models.CreateSecurityListDetails(
            compartment_id=self.compartment,
            vcn_id=vcn_id,
            display_name=display_name,
            ingress_security_rules=[],
            egress_security_rules=[]
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            create_sec_list_resp = composite_operation.create_security_list_and_wait_for_state(
                create_security_list_details=sec_list_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_sec_list_resp.data
    
    def get_ingress_security_rules(self, security_list_id):
        """Queries OCI for ingress security rules of a given security list

        Args:
            security_list_id (str): OCID of security list to query 

        Returns:
            - (True, list[oci.core.models.IngressSecurityRule]): Touple consisting of bool True and 
                        list of oci.core.models.IngressSecurityRule objects found for given security list
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query 
                        succeeded, but no given security list could not be found
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        
        try:
            security_lists = self.virtual_network_client.list_security_lists(self.compartment)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        for list in security_lists.data:
            if list.id == security_list_id:
                return True, list.ingress_security_rules
        return True, None
    
    def get_egress_security_rules(self, security_list_id):
        """Queries OCI for egress security rules of a given security list

        Args:
            security_list_id (str): OCID of security list to query 

        Returns:
            - (True, list[oci.core.models.EgressSecurityRule]): Touple consisting of bool True and 
                        list of oci.core.models.EgressSecurityRule objects found for given security list
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): Touple consisting of bool True and None object if query 
                        succeeded, but no given security list could not be found
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
     
        try:
            security_lists = self.virtual_network_client.list_security_lists(self.compartment)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        for list in security_lists.data:
            if list.id == security_list_id:
                return True, list.egress_security_rules
        return True, None

    def open_ingress_all(self, security_list_id, source_cidr, description, stateless=False):
        """Updates a given security list to add a rule opening all ingress ports from a given CIDR block

        Args:
            security_list_id (str): OCID of security list to update
            source_cidr (str): CIDR block of source to open all ports
            description (str): Description of rule
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if not self._is_valid_cidr(source_cidr):
            return False, f"CIDR block {source_cidr} is not valid"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        
        success, ret = self.get_ingress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        new_rule = oci.core.models.IngressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="all",
            source=source_cidr,
            source_type=oci.core.models.IngressSecurityRule.SOURCE_TYPE_CIDR_BLOCK,
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(ingress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_rules_resp.data

    def open_ingress_tcp_port(self, security_list_id, source, description, port, source_type="CIDR", stateless=False):
        """Adds a rule to a given security list opening a given ingress TCP port from a given source 

        Args:
            security_list_id (str): OCID of security list to which to add the rule
            source (str): Source IP or CIDR block depending on source_type
            description (str): Description of rule
            port (str|int): Port to open
            source_type (str, optional): Type of source: 'CIDR' or 'IP'. Defaults to 'CIDR'.
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if source_type == 'IP':
            if not self._is_valid_ip(source):
                return False, f"Source must be a valid IP, received {source}"
            source += "/32"
        elif source_type == 'CIDR':
            if not self._is_valid_cidr(source):
                return False, f"Source must be a valid CIDR block, received {source}"
        else:
            return False, f"Source type must be 'CIDR' or 'IP', received {source_type}"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not self._is_valid_port(port):
            return False, f"Port {port} is invalid"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        
        success, ret = self.get_ingress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        tcp_options = oci.core.models.TcpOptions(
            destination_port_range=oci.core.models.PortRange(min=int(port), max=int(port))
        )
        new_rule = oci.core.models.IngressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="6",
            source=source,
            source_type=oci.core.models.IngressSecurityRule.SOURCE_TYPE_CIDR_BLOCK,
            tcp_options=tcp_options
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(ingress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_rules_resp.data

    def open_ingress_udp_port(self, security_list_id, source_cidr, description, port, stateless=False):
        """Adds a rule to a given security list opening a given ingress UDP port from a given source CIDR

        Args:
            security_list_id (str): OCID of security list to which to add the rule
            source_cidr (str): CIDR of source
            description (str): Description of rule
            port (str|int): Port to open
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if not self._is_valid_cidr(source_cidr):
            return False, f"CIDR block {source_cidr} is not valid"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not self._is_valid_port(port):
            return False, f"Port {port} is invalid"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        success, ret = self.get_ingress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        udp_options = oci.core.models.UdpOptions(
            destination_port_range=oci.core.models.PortRange(min=int(port), max=int(port))
        )
        new_rule = oci.core.models.IngressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="17",
            source=source_cidr,
            source_type=oci.core.models.IngressSecurityRule.SOURCE_TYPE_CIDR_BLOCK,
            udp_options=udp_options
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(ingress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)

        return True, update_rules_resp.data

    def open_egress_all(self, security_list_id, destination_cidr, description, stateless=False):
        """Adds a rule to a given security list opening a given all egress ports to a given destination CIDR

        Args:
            security_list_id (str): OCID of security list to which to add the rule
            destination_cidr (str): CIDR of destination
            description (str): Description of rule
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if not self._is_valid_cidr(destination_cidr):
            return False, f"CIDR block {destination_cidr} is not valid"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        
        success, ret = self.get_egress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        new_rule = oci.core.models.EgressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="all",
            destination=destination_cidr,
            destination_type=oci.core.models.EgressSecurityRule.DESTINATION_TYPE_CIDR_BLOCK
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(egress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_rules_resp.data  

    def open_egress_tcp_port(self, security_list_id, destination_cidr, description, port, stateless=False):
        """Adds a rule to a given security list opening a given egress TCP port to a given destination CIDR

        Args:
            security_list_id (str): OCID of security list to which to add the rule
            destination_cidr (str): CIDR of destination
            description (str): Description of rule
            port (str|int): Port to open
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if not self._is_valid_cidr(destination_cidr):
            return False, f"CIDR block {destination_cidr} is not valid"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not self._is_valid_port(port):
            return False, f"Port {port} is invalid"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        success, ret = self.get_egress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        tcp_options = oci.core.models.TcpOptions(
            destination_port_range=oci.core.models.PortRange(min=int(port), max=int(port))
        )                   
        new_rule = oci.core.models.EgressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="6",
            destination=destination_cidr,
            destination_type=oci.core.models.EgressSecurityRule.DESTINATION_TYPE_CIDR_BLOCK,
            tcp_options=tcp_options
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(egress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_rules_resp.data

    def open_egress_port_osn(self, security_list_id, osn_cidr, description, port, stateless=False):
        """Adds a rule to a given security list opening a given egress TCP port to OSN

        Args:
            security_list_id (str): OCID of security list to which to add the rule
            osn_cidr (str): CIDR of OSN
            description (str): Description of rule
            port (str|int): Port to open
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not self._is_valid_port(port):
            return False, f"Port {port} is invalid"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        success, ret = self.get_egress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        tcp_options = oci.core.models.TcpOptions(
            destination_port_range=oci.core.models.PortRange(min=int(port), max=int(port))
        )                   
        new_rule = oci.core.models.EgressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="6",
            destination=osn_cidr,
            destination_type=oci.core.models.EgressSecurityRule.DESTINATION_TYPE_SERVICE_CIDR_BLOCK,
            tcp_options=tcp_options
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(egress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_rules_resp.data

    def open_egress_udp_port(self, security_list_id, destination_cidr, description, port, stateless=False):
        """Adds a rule to a given security list opening a given egress UDP port to a given destination CIDR

        Args:
            security_list_id (str): OCID of security list to which to add the rule
            destination_cidr (str): CIDR of destination
            description (str): Description of rule
            port (str|int): Port to open
            stateless (bool, optional): Whether to keep track of the TCP session state between 
                    the source and destination. Defaults to False.

        Returns:
            - (True, oci.core.models.SecurityList): Touple consisting of bool True and 
                        oci.core.models.SecurityList object of updated security list
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(security_list_id):
            return False, f"Security list ID {security_list_id} is not a valid OCID"
        if not self._is_valid_cidr(destination_cidr):
            return False, f"CIDR block {destination_cidr} is not valid"
        if not self._is_valid_description(description):
            return False, "Description is invalid - must only contain alphanum, '-', '_' or whitespace"
        if not self._is_valid_port(port):
            return False, f"Port {port} is invalid"
        if not isinstance(stateless, bool):
            return False, f"Parameter stateless expected to be of type bool, received {type(stateless).__name__}"
        success, ret = self.get_egress_security_rules(security_list_id)
        if not success:
            return False, ret
        if ret == None:
            return False, f"No security list found with id {security_list_id}"
        existing_rules = ret
        if existing_rules == None:
            return False, f"No security list found with id {security_list_id}"
        udp_options = oci.core.models.UdpOptions(
            destination_port_range=oci.core.models.PortRange(min=int(port), max=int(port))
        )                   
        new_rule = oci.core.models.EgressSecurityRule(
            description=description,
            is_stateless=stateless,
            protocol="17",
            destination=destination_cidr,
            destination_type=oci.core.models.EgressSecurityRule.DESTINATION_TYPE_CIDR_BLOCK,
            udp_options=udp_options
        )
        existing_rules.append(new_rule)
        update_model = oci.core.models.UpdateSecurityListDetails(egress_security_rules=existing_rules)
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_rules_resp = composite_operation.update_security_list_and_wait_for_state(
                security_list_id=security_list_id,
                update_security_list_details=update_model,
                wait_for_states=[oci.core.models.SecurityList.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_rules_resp.data 

    def create_subnet(self, vcn_id, cidr_block, subnet_name, is_private, security_list_ids: list, route_table_id):
        """Creates a new subnet in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to create subnet
            cidr_block (str): CIDR block to assign to subnet
            subnet_name (str): Name to assign to subnet
            is_private (bool): True if subnet should not have internet access, else False
            security_list_ids (list[str]): List of security list OCIDs to attach to subnet
            route_table_id (str): OCID of route table to attach to subnet

        Returns:
            - (True, oci.core.models.Subnet): Touple consisting of bool True and 
                        oci.core.models.Subnet object of newly created subnet
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_cidr(cidr_block):
            return False, f"CIDR block {cidr_block} is not valid"
        if not self._is_valid_name(subnet_name):
            return False, f"Subnet name {subnet_name} is not valid"
        if not isinstance(is_private, bool):
            return False, f"Parameter is_private expected to be of type bool, received {type(is_private).__name__}"
        if not isinstance(security_list_ids, list):
            return False, f"Parameter security_list_ids expected to be of type list[str], received {type(security_list_ids).__name__}"
        for id in security_list_ids:
            if not self._is_valid_ocid(id):
                return False, f"Security list ID {id} is not a valid OCID"
        if not self._is_valid_ocid(route_table_id):
            return False, f"Route Table ID {route_table_id} is not a valid OCID"

        dns_label = ""
        count = 0
        for char in subnet_name:
            if count > 15:
                break
            if char.isalnum():
                dns_label += char
                count += 1
        subnet_model = oci.core.models.CreateSubnetDetails(
            cidr_block=cidr_block,
            compartment_id=self.compartment,
            display_name=subnet_name,
            dns_label=dns_label,
            prohibit_public_ip_on_vnic=is_private,
            security_list_ids=security_list_ids,
            vcn_id=vcn_id,
            route_table_id=route_table_id
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            create_subnet_ret = composite_operation.create_subnet_and_wait_for_state(
                create_subnet_details=subnet_model,
                wait_for_states=[oci.core.models.Subnet.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_subnet_ret.data

    def create_dhcp_search_domain(self, vcn_id, search_domains, display_name):
        """Creates a new DHCP options of type Custome Search Domain in a given VCN

        Args:
            vcn_id (str): OCID of VCN in which to create DHCP option
            search_domains (str): Search domain to add
            display_name (str): Name to assign to DHCP option

        Returns:
            - (True, oci.core.models.DhcpOptions): Touple consisting of bool True and 
                        oci.core.models.DhcpOptions object of newly created DHCP option
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        if not self._is_valid_zone_name(search_domains):
            return False, f"Search domain {search_domains} is invalid"
        if not self._is_valid_name(display_name):
            return False, f"DHCP option name {display_name} is not valid"
        
        dhcp_model = oci.core.models.CreateDhcpDetails(
            compartment_id=self.compartment,
            options=[
                oci.core.models.DhcpSearchDomainOption(
                    type="SearchDomain",
                    search_domain_names=[search_domains]
                ),
                oci.core.models.DhcpDnsOption(server_type="VcnLocalPlusInternet")
            ],
            vcn_id=vcn_id,
            display_name=display_name
        )
        composite_operation=oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            create_dhcp_opt_ret = composite_operation.create_dhcp_options_and_wait_for_state(
                create_dhcp_details=dhcp_model,
                wait_for_states=[oci.core.models.DhcpOptions.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_dhcp_opt_ret.data
    
    def add_dhcp_opt_to_subnet(self, subnet_id, dhcp_opt_id,):
        """Adds a DHCP options to a given subnet

        Args:
            subnet_id (str): OCID of subnet to update
            dhcp_opt_id (str): OCID of DHCP option to add

        Returns:
            - (True, oci.core.models.Subnet): Touple consisting of bool True and 
                        oci.core.models.Subnet object of updated subnet
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(subnet_id):
            return False, f"Subnet ID {subnet_id} is not a valid OCID"
        if not self._is_valid_ocid(dhcp_opt_id):
            return False, f"DHCP option ID {dhcp_opt_id} is not a valid OCID"
        
        subnet_update_model = oci.core.models.UpdateSubnetDetails(
            dhcp_options_id=dhcp_opt_id
        )
        composite_operation = oci.core.VirtualNetworkClientCompositeOperations(self.virtual_network_client)
        try:
            update_resp = composite_operation.update_subnet_and_wait_for_state(
                subnet_id=subnet_id,
                update_subnet_details=subnet_update_model,
                wait_for_states=[oci.core.models.Subnet.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_resp.data


    def create_block_volume(self, availability_domain, name, size_in_gb):
        """Creates a new block volume in a given availability domain of a given size

        Args:
            availability_domain (str): Availability domain in which to create block volume
            name (str): Name to assign to block volume
            size_in_gb (int): Size of block volume in GB - must be bewtween 50 and 32768

        Returns:
            - (True, oci.core.models.Volume): Touple consisting of bool True and 
                        oci.core.models.Volume object of newly created block volume
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if availability_domain not in self.availability_domains:
            return False, f"Availability domain {availability_domain} not in current compartment's ADs"
        if not self._is_valid_name(name):
            return False, f"Block volume name {name} is invalid"
        try:
            if size_in_gb < 50 or size_in_gb > 32768:
                return False, f"Size must be between 50 and 32768 GB"
        except ValueError:
            return False, f"Size must be an integer between 50 and 32768"
        
        volume_model = oci.core.models.CreateVolumeDetails(
            availability_domain=availability_domain,
            compartment_id=self.compartment,
            display_name=name,
            size_in_gbs=size_in_gb,
        )
        composite_operation = oci.core.BlockstorageClientCompositeOperations(self.block_volume_client)
        try:
            ret = composite_operation.create_volume_and_wait_for_state(
                create_volume_details=volume_model,
                wait_for_states=[oci.core.models.Volume.LIFECYCLE_STATE_AVAILABLE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, ret.data
    
    def create_filesystem(self, availability_domain, name):
        """Creates a new filesystem in a given availability domain

        Args:
            availability_domain (str): Availability domain in which to create filesystem
            name (str): Name to assign to filesystem

        Returns:
            - (True, oci.file_storage.models.FileSystem): Touple consisting of bool True and 
                        oci.file_storage.models.FileSystem object of newly created filesystem
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if availability_domain not in self.availability_domains:
            return False, f"Availability domain {availability_domain} not in current compartment's ADs"
        if not self._is_valid_name(name):
            return False, f"Filesystem name {name} is invalid"
        fs_model = oci.file_storage.models.CreateFileSystemDetails(
            availability_domain=availability_domain,
            compartment_id=self.compartment,
            display_name=name
        )
        composite_operation = oci.file_storage.FileStorageClientCompositeOperations(self.file_storage_client)
        try:
            ret = composite_operation.create_file_system_and_wait_for_state(
                create_file_system_details=fs_model,
                wait_for_states=[oci.file_storage.models.FileSystem.LIFECYCLE_STATE_ACTIVE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, ret.data
    
    def create_mount_target(self, availability_domain, subnet_id, name):
        """Creates a new mount target in a given availability domain and given subnet

        Args:
            availability_domain (str): Availability domain in which to create filesystem
            subnet_id (str): OCID of subnet in which to create mount target
            name (str): Name to assign to mount target

        Returns:
            - (True, oci.file_storage.models.MountTarget): Touple consisting of bool True and 
                        oci.file_storage.models.MountTarget object of newly created mount target
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if availability_domain not in self.availability_domains:
            return False, f"Availability domain {availability_domain} not in current compartment's ADs"
        if not self._is_valid_ocid(subnet_id):
            return False, f"Subnet ID {subnet_id} is not a valid OCID"
        if not self._is_valid_name(name):
            return False, f"Mount target name {name} is invalid"
        
        mount_model = oci.file_storage.models.CreateMountTargetDetails(
            availability_domain=availability_domain,
            compartment_id=self.compartment,
            subnet_id=subnet_id,
            display_name=name
        )
        composite_operation = oci.file_storage.FileStorageClientCompositeOperations(self.file_storage_client)
        try:
            ret = composite_operation.create_mount_target_and_wait_for_state(
                create_mount_target_details=mount_model,
                wait_for_states=[oci.file_storage.models.MountTarget.LIFECYCLE_STATE_ACTIVE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, ret.data

    def get_private_ip_by_id(self, ip_id):
        """Queries OCI for the IP address of a private IP OCID

        Args:
            ip_id (str): OCID of private IP to query

        Returns:
            - (True, str): Touple consisting of bool True and IP address of private IP ID
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(ip_id):
            return False, f"Private IP ID {ip_id} is not a valid OCID"
        
        try:
            ret = self.virtual_network_client.get_private_ip(private_ip_id=ip_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, ret.data.ip_address

    def export_filesystem(self, export_set_id, filesystem_id, path):
        """Creates a filesystem export of a given filesystem in a given mount target's export set

        Args:
            export_set_id (str): Export set OCID of mount target
            filesystem_id (str): Filesystem OCID to export
            path (str): Export path

        Returns:
            - (True, oci.file_storage.models.Export): Touple consisting of bool True and 
                        oci.file_storage.models.Export object of newly created export
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(export_set_id):
            return False, f"Export set ID {export_set_id} is not a valid OCID"
        if not self._is_valid_ocid(filesystem_id):
            return False, f"Filesystem ID {filesystem_id} is not a valid OCID"
        if not self._is_valid_path(path):
            return False, f"Path {path} is invalid"
             
        export_model = oci.file_storage.models.CreateExportDetails(
            export_set_id=export_set_id,
            file_system_id=filesystem_id,
            path=path
        )
        composite_operation = oci.file_storage.FileStorageClientCompositeOperations(self.file_storage_client)
        try:
            ret = composite_operation.create_export_and_wait_for_state(
                create_export_details=export_model,
                wait_for_states=[oci.file_storage.models.Export.LIFECYCLE_STATE_ACTIVE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, ret.data

    def query_listing(self, name):
        """Queries OCI Marketplace for a listing of a given name

        Args:
            name (str): Name of listing to query for

        Returns:
            - (True, str): Touple consisting of bool True and OCID of found listing
            - (False, str): If query failed - touple consisting of bool False 
                        and exception encountered
            - (True, None): If query succeeded, but no listing found: touple 
                        consisting of bool True and None object
        """
        if not isinstance(name, str):
            return False, f"Listing name must be a string"
        try:
            listing = self.marketplace_client.list_listings(name=name)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if not len(listing.data):
            return True, None
        return True, listing.data[0].id

    def query_packages(self, listing_id, os_version):
        """Queries OCI for package version of a given listing and of a given os version

        Args:
            listing_id (str): Listing ID to query for
            os_version (str): OS version to query for

        Returns:
            - (True, str): Touple consisting of bool True and package version found
            - (False, str): If query failed - touple consisting of bool False 
                        and exception encountered
            - (True, None): If query succeeded, but no package version found: touple 
                        consisting of bool True and None object
        """
        if not self._is_valid_os_version(os_version):
            return False, f"OS version {os_version} is invalid"
        
        try:
            packages = self.marketplace_client.list_packages(listing_id=listing_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        if not len(packages.data):
            return True, None
        filtered_pkgs = [pkg for pkg in packages.data if f"ol{os_version}" in pkg.package_version and "forms" not in pkg.package_version.lower()]
        if not len(filtered_pkgs):
            return True, None
        return True, filtered_pkgs[0].package_version
    
    def get_package_details(self, listing_id, package_version):
        """Queries OCI for details of a given package version within a given listing

        Args:
            listing_id (str): ID of listing 
            package_version (str): Package version

        Returns:
            - (True, oci.marketplace.models.ListingPackage): Touple consisting of bool True and 
                        oci.marketplace.models.ListingPackage object of package details
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered   
        """
        try:
            package_details = self.marketplace_client.get_package(listing_id=listing_id, package_version=package_version)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, package_details.data

    def get_shape(self, shape_name):
        """Queries OCI for a given shape based on name

        Args:
            shape_name (str): Name of shape to query for

        Returns:
            - (True, oci.core.models.Shape): Touple consisting of bool True and 
                        oci.core.models.Shape object of shape found
            - (False, str): If query failed - touple consisting of bool False
                        and exception encountered
            - (True, None): If query succeeded, but no shape found: touple consisting
                        of bool True and None object    
        """
        try:
            shapes = self.compute_client.list_shapes(compartment_id=self.compartment)
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        for shape in shapes.data:
            if shape.shape == shape_name:
                return True, shape
        return True, None

    def provision_instance(self, type, name ,os_version, ocpu_count, memory, ssh_pub_key, subnet_id, availability_domain, init_script_path=None):
        """Provisions a compute instance in OCI

        Args:
            type (str): Type of instance. Allowed values are 'wls' and 'ohs'
            name (str): Name to assign to compute instance
            os_version (str): Oracle Linux version to use
            ocpu_count (int|str): Number of OCPUs
            memory (str|int): Memory size in GB
            ssh_pub_key (str): SSH public key to be used with instance
            subnet_id (str): OCID of subnet in which to create instance
            availability_domain (str): Availability domain in which to create instance
            init_script_path (str, optional): Absolute path of cloud init script to be used. Defaults to None.

        Returns:
            - (True, oci.core.models.Instance): Touple consisting of bool True and 
                        oci.core.models.Instance object of newly provisioned compute instance 
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered 
        """
        if type.lower() == 'wls':
            image = OciManager.weblogic_image
        elif type.lower() =='ohs':
            image = OciManager.ohs_image
        else:
            return False, f"Wrong value for parameter type: {type}"
        if not self._is_valid_name(name):
            return False, f"Instance name {name} is invalid"
        if not self._is_valid_os_version(os_version):
            return False, f"OS version {os_version} is invalid"
        try:
            if int(ocpu_count) < 1 or int(ocpu_count) > 114:
                return False, "OCPU count needs to be between 1 and 114"
        except ValueError:
            return False, "OCPU count needs to be an integer or int castable string between 1 and 114"
        try:
            if int(memory) < int(ocpu_count) or int(memory) > min(1776, int(ocpu_count) * 64):
                return False, "Memory size needs to be between minimum of 1 per OCPU and maximum of 64 per OCPU with a ceiling of 1776"
        except ValueError:
            return False, "Memory size needs to be an integer or int castable string between minimum of 1 per OCPU and maximum of 64 per OCPU with a ceiling of 1776"
        if not isinstance(ssh_pub_key, str) or not len(ssh_pub_key):
            return False, "SSH public key needs to be a non-blank string"
        if not self._is_valid_ocid(subnet_id):
            return False, f"Subnet ID {subnet_id} is not a valid OCID"
        if init_script_path is not None:
            if not self._is_valid_path(init_script_path):
                return False, f"Init script path {init_script_path} is invalid"
        if availability_domain not in self.availability_domains:
            return False, f"Availability domain {availability_domain} not in current compartment's ADs"
        
        success, ret = self.query_listing(name=image)
        if not success:
            return False, f"Could not query OCI for {image} image: {ret}"
        if ret is None:
            return False, f"No listing found for {image}"
        listing_id = ret
        success, ret = self.query_packages(listing_id, os_version)
        if not success:
            return False, f"Could not query OCI for package version: {ret}"
        if ret is None:
            return False, "No package version found"
        package_version = ret
        success, ret = self.get_package_details(listing_id=listing_id, package_version=package_version)
        if not success:
            return False, f"Could not query OCI for package details: {ret}"
        if ret is None:
            return False, "No package details found"
        package_details = ret
        catalog_listing_id = package_details.app_catalog_listing_id
        catalog_resource_version = package_details.app_catalog_listing_resource_version
        image_id = package_details.image_id
        resource_id = package_details.app_catalog_listing_id
        try:
            catalog_agreement = self.compute_client.get_app_catalog_listing_agreements(
                listing_id=catalog_listing_id,
                resource_version=catalog_resource_version
            )
        except oci.exceptions.ServiceError as e:
            return False, f"Failed getting catalog listing agreement: {e.message}"
        except Exception as e:
            return False, f"Failed getting catalog listing agreement: {repr(e)}"
        catalog_agreement = catalog_agreement.data
        subscription_model = oci.core.models.CreateAppCatalogSubscriptionDetails(
            compartment_id=self.compartment,
            listing_id=catalog_listing_id,
            listing_resource_version=catalog_resource_version,
            oracle_terms_of_use_link=catalog_agreement.oracle_terms_of_use_link,
            signature=catalog_agreement.signature,
            time_retrieved=catalog_agreement.time_retrieved
        )
        try:
            ret = self.compute_client.create_app_catalog_subscription(subscription_model)
        except oci.exceptions.ServiceError as e:
            return False, f"Failed creating app catalog subscription: {e.message}"
        except Exception as e:
            return False, f"Failed creating app catalog subscription: {repr(e)}"
        success, ret = self.get_shape(OciManager.shape_name)
        if not success:
            return False, f"Could not query OCI for shape details: {ret}"
        if ret is None:
            return False, "No shape found"
        shape = ret
        shape_config = oci.core.models.LaunchInstanceShapeConfigDetails(memory_in_gbs=int(memory), ocpus=int(ocpu_count))
        metadata = {
            'ssh_authorized_keys': ssh_pub_key
        }
        if init_script_path is not None:
            metadata['user_data'] = oci.util.file_content_as_launch_instance_user_data(init_script_path)
        source_image_model = oci.core.models.InstanceSourceViaImageDetails(image_id=image_id)
        vnic_model = oci.core.models.CreateVnicDetails(subnet_id=subnet_id)
        launch_instance_model = oci.core.models.LaunchInstanceDetails(
            display_name=name,
            compartment_id=self.compartment,
            availability_domain=availability_domain,
            shape=shape.shape,
            shape_config=shape_config,
            metadata=metadata,
            source_details=source_image_model,
            create_vnic_details=vnic_model,
        )
        composite_operation = oci.core.ComputeClientCompositeOperations(self.compute_client)
        try:
            launch_resp = composite_operation.launch_instance_and_wait_for_state(
                launch_instance_model,
                wait_for_states=[oci.core.models.Instance.LIFECYCLE_STATE_RUNNING]
            )
        except oci.exceptions.ServiceError as e:
            return False, f"Failed provisioning instance: {e.message}"
        except Exception as e:
            return False, f"Failed provisioning instance: {repr(e)}"
        return True, launch_resp.data

    def get_instance_ip(self, instance_id):
        """Queries OCI for the IP address of a given compute instance

        Args:
            instance_id (str): OCID of compute instance

        Returns:
            - (True, str): Touple consisting of bool True and IP address of compute instance
            - (False, str): If query failed - touple consisting of bool False 
                        and exception encountered
        """
        try:
            vnic_info = self.compute_client.list_vnic_attachments(compartment_id=self.compartment, instance_id=instance_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message 
        except Exception as e:
            return False, repr(e)

        try:
            ip_info = self.virtual_network_client.list_private_ips(vnic_id=vnic_info.data[0].vnic_id)
        except oci.exceptions.ServiceError as e:
            return False, e.message 
        except Exception as e:
            return False, repr(e)
        return True, ip_info.data[0].ip_address
    
    def attach_block_volume(self, node_id, volume_id):
        """Attaches a given volume to a given compute instance

        Args:
            node_id (str): OCID of instance to which to attach volume
            volume_id (str): OCID of volume to attach

        Returns:
            - (True, oci.core.models.VolumeAttachment): Touple consisting of bool True 
                        and oci.core.models.VolumeAttachment object of newly created attachment
            - (False, str): If attach operation failed - touple consisting of bool False 
                        and exception encountered
        """
        attachment_model = oci.core.models.AttachIScsiVolumeDetails(
            instance_id=node_id,
            volume_id=volume_id
        )
        composite_operation = oci.core.ComputeClientCompositeOperations(self.compute_client)
        try:
            ret = composite_operation.attach_volume_and_wait_for_state(
                attachment_model,
                wait_for_states=['ATTACHED']
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, ret.data
    
    def create_private_view(self, view_name):
        """Creates a new private view

        Args:
            view_name (str): Name of new view

        Returns:
            - (True, oci.dns.models.View): Touple consisting of bool True and 
                        oci.dns.models.View object with newly created view details
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_name(view_name):
            return False, f"View name {view_name} is invalid"
        
        view_model = oci.dns.models.CreateViewDetails(
            compartment_id=self.compartment,
            display_name=view_name
        )
        composite_operation = oci.dns.DnsClientCompositeOperations(self.dns_client)
        try:
            view_response = composite_operation.create_view_and_wait_for_state(
                create_view_details=view_model,
                wait_for_states=[oci.dns.models.View.LIFECYCLE_STATE_ACTIVE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, view_response.data
    
    def create_zone(self, zone_name, view_id):
        """Creates a new private zone in a given view

        Args:
            zone_name (str): zone name - complete domain of the hosts
            view_id (str): OCID of the view in which the zone will be created

        Returns:
            - (True, oci.dns.models.Zone): Touple consisting of bool True and 
                        oci.dns.models.Zone object with newly created zone details
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_zone_name(zone_name):
            return False, f"Zone name {zone_name} is invalid"
        if not self._is_valid_ocid(view_id):
            return False, f"View ID {view_id} is not a valid OCID"
        
        zone_model = oci.dns.models.CreateZoneDetails(
            compartment_id=self.compartment,
            name=zone_name,
            scope=oci.dns.models.CreateZoneDetails.SCOPE_PRIVATE,
            view_id=view_id,
            zone_type=oci.dns.models.CreateZoneDetails.ZONE_TYPE_PRIMARY
            )
        composite_operation = oci.dns.DnsClientCompositeOperations(self.dns_client)
        try:
            zone_response = composite_operation.create_zone_and_wait_for_state(
                zone_model,
                operation_kwargs={'scope': oci.dns.models.Zone.SCOPE_PRIVATE},
                wait_for_states=[oci.dns.models.Zone.LIFECYCLE_STATE_ACTIVE]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, zone_response.data
    
    def add_ipv4_record_to_zone(self, zone_id, zone_name, host, ip):
        """Creates a new record of type A (IPv4 Address) in a given zone by retrieving 
        a list of all records in zone, appending new record to the list and calling 
        update_zone_records() with updated list. 
        This is because update_zone_records() replaces all records with the 
        list passed to it.


        Args:
            zone_id (str): OCID of zone in which to create record
            zone_name (str): Name of zone in which to create record (which is the FQDN)
            host (str): Hostname of host - will be display name of record
            ip (str): IPv4 address where <host> should be routed 

        Returns:
            - (True, list[oci.dns.models.Record]): Touple consisting of bool True and 
                        list of oci.dns.models.Record objects of all records in given zone 
                        including the newly created one
            - (False, str): If creation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(zone_id):
            return False, f"Zone ID {zone_id} is not a valid OCID"
        if not self._is_valid_zone_name(zone_name):
            return False, f"Zone name {zone_name} is invalid"
        if not self._is_valid_domain(host):
            return False, f"Host {host} is invalid record name"
        if not self._is_valid_ip(ip):
            return False, f"IP {ip} is invalid"
        
        existing_records = self.dns_client.get_zone_records(zone_name_or_id=zone_id)
        existing_records = existing_records.data.items
        updated_records = []
        for record in existing_records:
            updated_records.append(
                oci.dns.models.RecordDetails(
                    domain=record.domain, 
                    is_protected=record.is_protected, 
                    rdata=record.rdata, 
                    record_hash=record.record_hash, 
                    rrset_version=record.rrset_version, 
                    rtype=record.rtype, 
                    ttl=record.ttl)                    
                )
        updated_records.append(
            oci.dns.models.RecordDetails(
                domain=f"{host}.{zone_name}",
                rdata=ip,
                rtype='A',
                ttl=120
            )
        )
        update_zone_records_model = oci.dns.models.UpdateZoneRecordsDetails(items=updated_records)
        try:
            update_records_response = self.dns_client.update_zone_records(
                zone_name_or_id=zone_id, 
                update_zone_records_details=update_zone_records_model
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_records_response.data
    
    def attach_view_to_dns_resolver(self, view_id, vcn_id):
        """Attaches a view to a VCN's resolver

        Args:
            view_id (str): OCID of view to attach
            vcn_id (str): OCID of VCN to which to attach the view

        Returns:
            - (True, oci.dns.models.resolver.Resolver): Touple consisting of bool True and 
                        oci.dns.models.resolver.Resolver object of updated resolver 
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(view_id):
            return False, f"View ID {view_id} is not a valid OCID"
        if not self._is_valid_ocid(vcn_id):
            return False, f"VCN ID {vcn_id} is not a valid OCID"
        
        resolvers = self.dns_client.list_resolvers(self.compartment)
        resolver = None
        for res in resolvers.data:
            if res.attached_vcn_id == vcn_id:
                resolver = res
        if resolver is None:
            return False, "Could not retrieve VCN resolver"
        resolver_data = self.dns_client.get_resolver(resolver_id=resolver.id)
        resolver_data = resolver_data.data
        update_model = oci.dns.models.UpdateResolverDetails()
        update_model.attached_views = []
        for view in resolver_data.attached_views:
            update_model.attached_views.append(
                oci.dns.models.AttachedViewDetails(view_id=view.view_id)
            )
        update_model.attached_views.append(
            oci.dns.models.AttachedViewDetails(view_id=view_id)
        )
        try:
            update_response = self.dns_client.update_resolver(
                resolver_id=resolver_data.id, 
                update_resolver_details=update_model
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, update_response.data

 
    def provision_lbr(self, min_bandwith_mbs, max_bandwith_mbs, name, subnet_id, is_private):
        """Creates a Load Balancer in a given subnet

        Args:
            min_bandwith_mbs (str|int): Minimum LBR bandwidth value (10-4800)
            max_bandwith_mbs (str|int): Maximum LBR bandwidth (10-4800)
            name (str): Name of LBR to create
            subnet_id (str): OCID of subnet in which to create LBR
            is_private (bool): Specify if LBR is private or public (if subnet is private, LBR must be private as well)

        Returns:
            - (True, oci.load_balancer.models.LoadBalancer): Touple consisting of bool True and 
                        oci.load_balancer.models.LoadBalancer object of newly created LBR
            - (False, str): If update failed - touple consisting of bool False
                        and exception encountered
        """
        try:
            if int(min_bandwith_mbs) < 10 or int(min_bandwith_mbs) > 4800:
                raise Exception
        except Exception:
            return False, "min_bandwith_mbs needs to be a number between 10 and 4800"
        try:
            if int(max_bandwith_mbs) < 10 or int(max_bandwith_mbs) > 4800:
                raise Exception
        except Exception:
            return False, "max_bandwith_mbs needs to be a number between 10 and 4800"
        if not self._is_valid_name(name):
            return False, f"LBR name {name} is not valid"
        if not self._is_valid_ocid(subnet_id):
            return False, f"Subnet ID {subnet_id} is not a valid OCID"
        if not isinstance(is_private, bool):
            return False, f"is_private expected to be bool, received {type(is_private).__name__}"
        
        lbr_shape_model = oci.load_balancer.models.ShapeDetails(
            minimum_bandwidth_in_mbps=int(min_bandwith_mbs),
            maximum_bandwidth_in_mbps=int(max_bandwith_mbs)
        )

        lbr_model = oci.load_balancer.models.CreateLoadBalancerDetails(
            compartment_id=self.compartment,
            display_name=name,
            shape_name="flexible",
            shape_details=lbr_shape_model,
            subnet_ids=[subnet_id],
            is_private=is_private
        )
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            provision_lbr_response = composite_operation.create_load_balancer_and_wait_for_state(
                create_load_balancer_details=lbr_model,
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, provision_lbr_response.data


    def load_lbr_certificate(self, load_balancer_id, name, public_certificate, private_key, ca_certificate="", passphrase=""):
        """Uploads and assigns a certifiate to a given LBR

        Args:
            load_balancer_id (str): OCID of load balancer
            name (str): OCI display to assign to certificate 
            public_certificate (str): String containing private certificate
            private_key (str): String containing private key
            ca_certificate (str, optional): String containing CA certificate. 
                        Defaults to "" in which the public certificate will be used as the CA certificate.
            passphrase (str, optional): Certificate passphrase. Defaults to "" in which case no passphrase is used.

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request to upload and assign certificate
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(load_balancer_id):
            return False, f"Load Balancer ID {load_balancer_id} is not a valid OCID"
        if not self._is_valid_name(name):
            return False, f"Certificate name {name} is not valid"
        
        kwargs = dict()
        kwargs['certificate_name'] = name
        kwargs['public_certificate'] = public_certificate
        kwargs['private_key'] = private_key
        if ca_certificate != "":
            kwargs['ca_certificate'] = ca_certificate
        else:
            kwargs['ca_certificate'] = public_certificate
        if passphrase != "":
            kwargs['passphrase'] = passphrase
        create_certificate_model = oci.load_balancer.models.CreateCertificateDetails(**kwargs)
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            create_cert_resp = composite_operation.create_certificate_and_wait_for_state(
                create_certificate_details=create_certificate_model,
                load_balancer_id=load_balancer_id,
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_cert_resp.data
        

    def lbr_create_backend_set(self, 
                           load_balancer_id, 
                           backend_set_name, 
                           healthcheck_port, 
                           cookie_name=None, 
                           cookie_is_http_only=True,
                           cookie_is_secure=False,
                           policy='ROUND_ROBIN',
                           healthcheck_interval=10000, 
                           healthcheck_protocol='HTTP',
                           healthcheck_retries=3, 
                           healthcheck_status_code=200, 
                           healthcheck_timeout=3000, 
                           healthcheck_url='/'):
        """Creates a backend set for a given LBR

        Args:
            load_balancer_id (str): OCID of load balancer
            backend_set_name (str): Name of backend set to create
            healthcheck_port (str|int): Health check port of backend set. Number between 1 and 65536
            cookie_name (str, optional): Name of load balancer cookie persistance. 
                        Defaults to None in which case session-based cookie persistence is not used.
            cookie_is_http_only (bool, optional): Whether the Set-cookie header should contain the HttpOnly attribute. 
                        Defaults to True.
            cookie_is_secure (bool, optional): Whether the Set-cookie header should contain the Secure attribute. 
                        Defaults to False.
            policy (str, optional): The load balancer policy for the backend set. Must be one of 'ROUND_ROBIN', 'LEAST_CONNECTIONS', 'IP_HASH'
                        Defaults to 'ROUND_ROBIN'.
            healthcheck_interval (int, optional): The interval between health checks, in milliseconds. 
                        Defaults to 10000.
            healthcheck_protocol (str, optional): The protocol the health check must use. Must be one of 'HTTP' or 'TCP'
                        Defaults to 'HTTP'.
            healthcheck_retries (int, optional): The number of retries to attempt before a backend server is considered unhealthy. 
                        Defaults to 3.
            healthcheck_status_code (int, optional): The status code a healthy backend server should return. 
                        Defaults to 200.
            healthcheck_timeout (int, optional):  The maximum time, in milliseconds, to wait for a reply to a health check. 
                        Defaults to 3000.
            healthcheck_url (str, optional): The path against which to run the health check. 
                        Defaults to '/'.

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request to create a backend set
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(load_balancer_id):
            return False, f"Load Balancer ID {load_balancer_id} is not a valid OCID"
        if not self._is_valid_name(backend_set_name):
            return False, f"Backend set name {backend_set_name} is not valid"
        if cookie_name is not None:
            if not self._is_valid_name(cookie_name):
                return False, f"Cookie name {cookie_name} is not valid"
        if not self._is_valid_port(healthcheck_port):
            return False, f"Health check port {healthcheck_port} is not valid"
        if not isinstance(cookie_is_http_only, bool):
            return False, f"cookie_is_http_only expected bool, received {type(cookie_is_http_only).__name__}"
        if not isinstance(cookie_is_secure, bool):
            return False, f"cookie_is_http_only expected bool, received {type(cookie_is_secure).__name__}"
        if policy not in ['ROUND_ROBIN', 'LEAST_CONNECTIONS', 'IP_HASH']:
            return False, f"Invalid policy [{policy}]. Must be one of 'ROUND_ROBIN', 'LEAST_CONNECTIONS', 'IP_HASH'"
        try:
            if int(healthcheck_interval) < 1000 or int(healthcheck_interval) > 1800000:
                raise Exception
        except Exception:
            return False, "Health check interval must be a number (str|int) between 1000 and 1800000"
        if healthcheck_protocol not in ['HTTP', 'TCP']:
            return False, f"Health check protocol [{healthcheck_protocol}] invalid. Must be one of 'HTTP', 'TCP'"
        try:
            if int(healthcheck_retries) < 1:
                raise Exception
        except Exception:
            return False, "Health check retries must be a number (str|int) greater than 1"
        try:
            if int(healthcheck_status_code) < 100 or int(healthcheck_status_code) > 599:
                raise Exception
        except Exception:
            return False, "Health check status code must be a number (str|int) between 100 and 599"
        try:
            if int(healthcheck_timeout) < 1 or int(healthcheck_timeout) > 600000:
                raise Exception
        except Exception:
            return False, "Health check timeout must be a number (str|int) between 1 and 600000"
        if int(healthcheck_interval) < int(healthcheck_timeout):
            return False, "Health check interval must be greater than health check timeout."
        
        kwargs = {}
        healthcheck_model = oci.load_balancer.models.HealthCheckerDetails(
            interval_in_millis=int(healthcheck_interval),
            port=int(healthcheck_port),
            protocol=healthcheck_protocol,
            retries=healthcheck_retries,
            return_code=healthcheck_status_code,
            timeout_in_millis=healthcheck_timeout,
            url_path=healthcheck_url
        )
        kwargs['health_checker'] = healthcheck_model
        if cookie_name is not None:
            lb_cookie_pers_model = oci.load_balancer.models.LBCookieSessionPersistenceConfigurationDetails(
                cookie_name=cookie_name,
                is_http_only=cookie_is_http_only,
                is_secure=cookie_is_secure
            )
            kwargs['lb_cookie_session_persistence_configuration'] = lb_cookie_pers_model
        kwargs['name'] = backend_set_name
        kwargs['policy'] = policy
        backend_set_model = oci.load_balancer.models.CreateBackendSetDetails(**kwargs)
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            create_backend_set_resp = composite_operation.create_backend_set_and_wait_for_state(
                create_backend_set_details=backend_set_model,
                load_balancer_id=load_balancer_id,
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_backend_set_resp.data

    def add_backend_to_set(self, lbr_id, backend_set_name, backend_ip, backend_port):
        """Adds a backend to a given backend set

        Args:
            lbr_id (str): OCID of load balancer
            backend_set_name (str): The name of the backend set to add the backend server to
            backend_ip (str): The IP address of the backend server.
            backend_port (int|str): The communication port for the backend server. Number between 1 and 65536

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request to 
                        add a backend server to a backend set
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(lbr_id):
            return False, f"Load Balancer ID {lbr_id} is not a valid OCID"
        if not self._is_valid_name(backend_set_name):
            return False, f"Backend set name {backend_set_name} is not valid"
        if not self._is_valid_ip(backend_ip):
            return False, f"Backend IP {backend_ip} is not valid"
        if not self._is_valid_port(backend_port):
            return False, f"Port {backend_port} is not valid"
        
        backend_model = oci.load_balancer.models.CreateBackendDetails(ip_address=backend_ip, port=int(backend_port))
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            add_backend_response = composite_operation.create_backend_and_wait_for_state(
                create_backend_details=backend_model,
                load_balancer_id=lbr_id,
                backend_set_name=backend_set_name,
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, add_backend_response.data

    def create_lbr_virtual_hostname(self, lbr_id, hostname_name, hostname):
        """Creates a virtual hostname for a given LBR

        Args:
            lbr_id (str): OCID of load balancer
            hostname_name (str): OCI display name of hostname
            hostname (str): Virtual hostname

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request 
                        to create a virtual hostname
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(lbr_id):
            return False, f"Load Balancer ID {lbr_id} is not a valid OCID"
        if not self._is_valid_name(hostname_name):
            return False, f"Hostname name {hostname_name} is not valid"
        if not self._is_valid_record_name(hostname):
            return False, f"Hostname {hostname} is not valid"
        
        hostname_model = oci.load_balancer.models.CreateHostnameDetails(name=hostname_name, hostname=hostname)
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            create_hostname_response = composite_operation.create_hostname_and_wait_for_state(
                create_hostname_details=hostname_model,
                load_balancer_id=lbr_id,
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_hostname_response.data

    def lbr_create_listener(self, lbr_id, listener_name, backend_set_name, hostname_name, port, ruleset_names=None, protocol='HTTP', use_ssl=False, certificate_name=None):
        """Creates a listener in a given LBR

        Args:
            lbr_id (str): OCID of load balancer
            listener_name (str): OCI display name of listener
            backend_set_name (str): The name of the backend set to associate to this listener.
            hostname_name (str): OCI display name of hostname to associate to this listener.
            port (int|str): The communication port for the listener. Number between 1 and 65536
            ruleset_names (list[str], optional): OCI display name of rule set to associate to this listener. 
                        Defaults to None in which case no rule set is associated.
            protocol (str, optional): The protocol on which the listener accepts connection requests. 
                        Must be one of 'HTTP', 'HTTP2', 'TCP'. Defaults to 'HTTP'.
            use_ssl (bool, optional): Whether the listener uses SSL. Defaults to False.
            certificate_name (str, optional): OCI display name of certificate this listener should use. 
                        Required if use_ssl is True. Defaults to None.

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request to create a listener
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(lbr_id):
            return False, f"Load Balancer ID {lbr_id} is not a valid OCID"
        if not self._is_valid_name(listener_name):
            return False, f"Listener name {listener_name} is not valid"  
        if not self._is_valid_name(backend_set_name):
            return False, f"Backend set name {backend_set_name} is not valid"
        if not self._is_valid_name(hostname_name):
            return False, f"Hostname name {hostname_name} is not valid"        
        if not self._is_valid_port(port):
            return False, f"Port {port} is not valid"
        if ruleset_names is not None:
            if not isinstance(ruleset_names, list):
                return False, f"ruleset_names expected to be list, received {type(ruleset_names).__name__}"
            for name in ruleset_names:
                if not self._is_valid_name(name):
                    return False, f"Rule set name {name} is not valid"  
        if protocol not in ['HTTP', 'HTTP2', 'TCP']:
            return False, "Protocol must be one of 'HTTP', 'HTTP2', 'TCP'"
        if not isinstance(use_ssl, bool):
            return False, f"use_ssl expected to be bool, received {type(use_ssl).__name__}"
        if use_ssl:
            if not self._is_valid_name(certificate_name):
                return False, f"Certificate name {certificate_name} is not valid"
            
        kwargs = {}
        kwargs['default_backend_set_name'] = backend_set_name
        kwargs['hostname_names'] = hostname_name,
        kwargs['name'] = listener_name
        kwargs['port'] = int(port)
        kwargs['protocol'] = protocol
        if use_ssl:
            ssl_conf_model = oci.load_balancer.models.SSLConfigurationDetails(certificate_name=certificate_name)
            kwargs['ssl_configuration'] = ssl_conf_model
        if ruleset_names is not None:
            kwargs['rule_set_names'] = ruleset_names
        listener_model = oci.load_balancer.models.CreateListenerDetails(**kwargs)
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            create_listener_response = composite_operation.create_listener_and_wait_for_state(
                create_listener_details=listener_model, 
                load_balancer_id=lbr_id, 
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_listener_response.data
    
    def lbr_create_ssl_headers_ruleset(self, lbr_id, ruleset_name):
        """Creates a rule set to add the following HTTP request headers:
                     - header is_ssl with value ssl
                     - header WL-Proxy-SSL with value true

        Args:
            lbr_id (str): OCID of load balancer
            ruleset_name (str): Rule set name

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request to create rule set
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(lbr_id):
            return False, f"Load Balancer ID {lbr_id} is not a valid OCID"
        if not self._is_valid_name(ruleset_name):
            return False, f"Rule set name {ruleset_name} is not valid"
        
        items = [
            oci.load_balancer.models.AddHttpRequestHeaderRule(
                action=oci.load_balancer.models.AddHttpRequestHeaderRule.ACTION_ADD_HTTP_REQUEST_HEADER, 
                header="is_ssl",
                value="ssl"),
            oci.load_balancer.models.AddHttpRequestHeaderRule(
                action=oci.load_balancer.models.AddHttpRequestHeaderRule.ACTION_ADD_HTTP_REQUEST_HEADER, 
                header="WL-Proxy-SSL", 
                value="true")
        ]
        ruleset_model = oci.load_balancer.models.CreateRuleSetDetails(items=items, name='SSLHeaders')
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            create_ruleset_response = composite_operation.create_rule_set_and_wait_for_state(
                load_balancer_id=lbr_id, 
                create_rule_set_details=ruleset_model, 
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_ruleset_response.data

    def lbr_create_http_redirect_ruleset(self, lbr_id, ruleset_name):
        """Creates a HTTP to HTTPS redirect rule set

        Args:
            lbr_id (str): OCID of load balancer
            ruleset_name (str): Rule set name

        Returns:
            - (True, oci.load_balancer.models.WorkRequest): Touple consisting of bool True and 
                        oci.load_balancer.models.WorkRequest object of successful work request to create rule set
            - (False, str): If operation failed - touple consisting of bool False
                        and exception encountered
        """
        if not self._is_valid_ocid(lbr_id):
            return False, f"Load Balancer ID {lbr_id} is not a valid OCID"
        if not self._is_valid_name(ruleset_name):
            return False, f"Rule set name {ruleset_name} is not valid"
        
        rule_condition_model = oci.load_balancer.models.PathMatchCondition(
            attribute_name=oci.load_balancer.models.PathMatchCondition.ATTRIBUTE_NAME_PATH,
            attribute_value="/",
            operator=oci.load_balancer.models.PathMatchCondition.OPERATOR_FORCE_LONGEST_PREFIX_MATCH
        )
        redirect_uri_model = oci.load_balancer.models.RedirectUri(
            host="{host}",
            path="/{path}",
            port=443,
            protocol="HTTPS",
            query="?{query}"
        )
        redirect_rule_model = oci.load_balancer.models.RedirectRule(
            action=oci.load_balancer.models.RedirectRule.ACTION_REDIRECT,
            conditions=[rule_condition_model],
            redirect_uri=redirect_uri_model,
            response_code=301
        )
        rule_model = oci.load_balancer.models.CreateRuleSetDetails(
            items=[redirect_rule_model],
            name=ruleset_name
        )
        
        composite_operation = oci.load_balancer.LoadBalancerClientCompositeOperations(self.lbr_client)
        try:
            create_ruleset_response = composite_operation.create_rule_set_and_wait_for_state(
                load_balancer_id=lbr_id, 
                create_rule_set_details=rule_model, 
                wait_for_states=[oci.load_balancer.models.WorkRequest.LIFECYCLE_STATE_SUCCEEDED]
            )
        except oci.exceptions.ServiceError as e:
            return False, e.message
        except Exception as e:
            return False, repr(e)
        return True, create_ruleset_response.data