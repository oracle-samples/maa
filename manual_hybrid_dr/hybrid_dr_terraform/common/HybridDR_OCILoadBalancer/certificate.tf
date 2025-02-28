## WLS Hybrid DR terraform scripts  
##
## Copyright (c) 2022 Oracle and/or its affiliates
## Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
##

########################################################################################################
# Configure SSL certificate in the LBR
########################################################################################################
resource "oci_load_balancer_certificate" "hy_https_certificate" {
  # This is when the cert has no passphrase
  count = var.certificate_passphrase == "" ? 1 : 0
  #Required
  certificate_name = "hy_https_cert"
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id

  #Optional
  ca_certificate     = file(var.certificate_ca_certificate_file)
  private_key        = file(var.certificate_private_key_file)
  public_certificate = file(var.certificate_public_certificate_file)

  lifecycle {
    create_before_destroy = true
  }
}

resource "oci_load_balancer_certificate" "hy_https_certificate_withpass" {
  # This is in case the cert has passwphrase
  count = var.certificate_passphrase != "" ? 1 : 0
  #Required
  certificate_name = "hy_https_cert"
  load_balancer_id = oci_load_balancer_load_balancer.hydr_LBR.id

  #Optional
  ca_certificate     = file(var.certificate_ca_certificate_file)
  passphrase         = var.certificate_passphrase
  private_key        = file(var.certificate_private_key_file)
  public_certificate = file(var.certificate_public_certificate_file)

  lifecycle {
    create_before_destroy = true
  }
}

