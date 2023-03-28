# Create Edge VPC
resource "google_compute_network" "edge_vpc" {
  project                 = var.project
  name                    = var.edge_vpc_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# Create subnets for Edge VPC, each subnet map to a region.
resource "google_compute_subnetwork" "edge_vpc_subnets" {
  for_each      = var.regional_config
  project       = var.project
  region        = each.key
  name          = "${var.edge_vpc_name}-subnet-${each.key}"
  ip_cidr_range = each.value.edge_vpc_subnet_ip_cidr_range
  network       = google_compute_network.edge_vpc.id
}

# Create cloud routers per subnet per region.
resource "google_compute_router" "edge_vpc_subnet_cloud_routers" {
  for_each = var.regional_config
  project  = var.project
  region   = each.key
  name     = "${var.edge_vpc_name}-cr-${each.key}"
  network  = google_compute_network.edge_vpc.name
  bgp {
    asn               = each.value.cr_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = []

    advertised_ip_ranges {
      range = each.value.private_service_connection_ip_range
    }
  }
  depends_on = [
    google_compute_subnetwork.edge_vpc_subnets
  ]
}

# Provsion the first interface of CR
resource "google_compute_router_interface" "cr_interface_1" {
  for_each           = var.regional_config
  project            = var.project
  region             = each.key
  name               = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-interface-1"
  router             = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork         = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  private_ip_address = cidrhost(each.value.edge_vpc_subnet_ip_cidr_range, (pow(2, (32 - tonumber(split("/", each.value.edge_vpc_subnet_ip_cidr_range)[1]))) - 4))
}

# Provsion the second interface of CR
resource "google_compute_router_interface" "cr_interface_2" {
  for_each           = var.regional_config
  project            = var.project
  region             = each.key
  name               = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-interface-2"
  router             = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork         = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  private_ip_address = cidrhost(each.value.edge_vpc_subnet_ip_cidr_range, (pow(2, (32 - tonumber(split("/", each.value.edge_vpc_subnet_ip_cidr_range)[1]))) - 3))
}


# Private Service Connection IP Range allocations
resource "google_compute_global_address" "private_service_connection_ip_range" {
  for_each      = var.regional_config
  project       = var.project
  name          = "${var.edge_vpc_name}-psc-${each.key}"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = google_compute_network.edge_vpc.id
  ip_version    = "IPV4"
  address       = split("/", each.value.private_service_connection_ip_range)[0]
  prefix_length = tonumber(split("/", each.value.private_service_connection_ip_range)[1])
}

# Equivlent to VPC -> Private Service Connection -> Private Connections to Services -> Select Google Cloud Platform as Connected service producer, and check allocated IP ranges.
resource "google_service_networking_connection" "psc_generic" {
  network                 = google_compute_network.edge_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for k, v in google_compute_global_address.private_service_connection_ip_range : v.name]
}

# Make sure the VPC peering with the Private Service Connection will export custom route
resource "google_compute_network_peering_routes_config" "private_service_access_generic" {


  project = var.project
  peering = google_service_networking_connection.psc_generic.peering
  network = google_compute_network.edge_vpc.name

  import_custom_routes = false
  export_custom_routes = true # We change this from the default to export our custom routes

}


# Build Aviatrix Transit
module "mc-transit" {
  for_each               = var.regional_config
  source                 = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version                = "2.4.1" # Lookup module version to controller version mapping: https://registry.terraform.io/modules/terraform-aviatrix-modules/mc-transit/aviatrix/latest
  cloud                  = "GCP"
  region                 = each.key
  cidr                   = each.value.aviatrix_transit_vpc_subnet_ip_cidr_range
  account                = var.account
  enable_bgp_over_lan    = true
  enable_transit_firenet = false
  name                   = each.value.aviatrix_transit_vpc_name
  gw_name                = each.value.aviatrix_transit_gateway_name
  bgp_lan_interfaces = [{
    vpc_id = google_compute_network.edge_vpc.name
    subnet = each.value.edge_vpc_subnet_ip_cidr_range
  }]
  ha_bgp_lan_interfaces = [{
    vpc_id = google_compute_network.edge_vpc.name
    subnet = each.value.edge_vpc_subnet_ip_cidr_range
  }]
  local_as_number = each.value.avx_transit_asn
}

# Create NCC hub
resource "google_network_connectivity_hub" "gcc_ncc_hub" {
  for_each = var.regional_config
  project  = var.project
  name     = "${each.value.aviatrix_transit_vpc_name}-ncc-hub"
}

# Create NCC spoke and associate with hub

resource "google_network_connectivity_spoke" "gcp_ncc_spoke" {
  for_each = var.regional_config
  project  = var.project
  name     = "${each.value.aviatrix_transit_vpc_name}-ncc-spoke"
  location = each.key
  hub      = google_network_connectivity_hub.gcc_ncc_hub[each.key].id
  linked_router_appliance_instances {
    instances {
        virtual_machine = "https://www.googleapis.com/compute/v1/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.vpc_reg}/instances/${module.mc-transit[each.key].transit_gateway.gw_name}"
        ip_address = module.mc-transit[each.key].transit_gateway.bgp_lan_ip_list[0]
    }
    instances {
        virtual_machine = "https://www.googleapis.com/compute/v1/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.ha_zone}/instances/${module.mc-transit[each.key].transit_gateway.ha_gw_name}"
        ip_address = module.mc-transit[each.key].transit_gateway.ha_bgp_lan_ip_list[0]
    }
    site_to_site_data_transfer = true
  }
}
