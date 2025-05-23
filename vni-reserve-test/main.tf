########################################################################################################################
# Resource Group
########################################################################################################################

module "resource_group" {
  source  = "terraform-ibm-modules/resource-group/ibm"
  version = "1.2.0"
  # if an existing resource group is not set (null) create a new one using prefix
  resource_group_name          = var.resource_group == null ? "${local.prefix_region}-resource-group" : null
  existing_resource_group_name = var.resource_group
}

locals {
  prefix_region = "${var.prefix}-${var.region}"
}
########################################################################################################################
# VPC + Subnet + Public Gateway
#
# NOTE: This is a very simple VPC with single subnet in a single zone with a public gateway enabled, that will allow
# all traffic ingress/egress by default.
# For production use cases this would need to be enhanced by adding more subnets and zones for resiliency, and
# ACLs/Security Groups for network security.
########################################################################################################################

resource "ibm_is_vpc" "vpc" {
  name                      = "${local.prefix_region}-vpc"
  resource_group            = module.resource_group.resource_group_id
  address_prefix_management = "auto"
}

resource "ibm_is_public_gateway" "gateway" {
  name           = "${local.prefix_region}-gateway-1"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = module.resource_group.resource_group_id
  zone           = "${var.region}-1"
}

resource "ibm_is_subnet" "subnet_zone_1" {
  name                     = "${local.prefix_region}-subnet-1"
  vpc                      = ibm_is_vpc.vpc.id
  resource_group           = module.resource_group.resource_group_id
  zone                     = "${var.region}-1"
  total_ipv4_address_count = 256
  public_gateway           = ibm_is_public_gateway.gateway.id
}

resource "ibm_is_subnet_reserved_ip" "reserve_ip" {
  name        = "${local.prefix_region}-ip"
  subnet      = ibm_is_subnet.subnet_zone_1.id
  auto_delete = false
}

resource "ibm_is_virtual_network_interface" "primary_vni" {
  name                      = "${local.prefix_region}-vni"
  subnet                    = ibm_is_subnet.subnet_zone_1.id
  resource_group            = module.resource_group.resource_group_id
  auto_delete               = false
  enable_infrastructure_nat = true

  # dynamic "primary_ip" {
  #   for_each = [1]
  #   content {
  #     reserved_ip = ibm_is_subnet_reserved_ip.reserve_ip.reserved_ip
  #   }
  # }

  primary_ip {
    reserved_ip = ibm_is_subnet_reserved_ip.reserve_ip.reserved_ip
  }
}
