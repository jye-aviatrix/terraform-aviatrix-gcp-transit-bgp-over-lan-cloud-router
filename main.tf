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

#Provision Cloud Router primary interface address
resource "google_compute_address" "cr_primary_addr" {
  for_each     = var.regional_config
  project      = var.project
  name         = "${var.edge_vpc_name}-${each.key}-cr-primary-addr"
  region       = google_compute_subnetwork.edge_vpc_subnets[each.key].region
  subnetwork   = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  address_type = "INTERNAL"
  address      = cidrhost(each.value.edge_vpc_subnet_ip_cidr_range, (pow(2, (32 - tonumber(split("/", each.value.edge_vpc_subnet_ip_cidr_range)[1]))) - 4))
}

#Provision Cloud Router redundant interface address
resource "google_compute_address" "cr_redundant_addr" {
  for_each     = var.regional_config
  project      = var.project
  name         = "${var.edge_vpc_name}-${each.key}-cr-redundant-addr"
  region       = google_compute_subnetwork.edge_vpc_subnets[each.key].region
  subnetwork   = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  address_type = "INTERNAL"
  address      = cidrhost(each.value.edge_vpc_subnet_ip_cidr_range, (pow(2, (32 - tonumber(split("/", each.value.edge_vpc_subnet_ip_cidr_range)[1]))) - 3))
}

# Create Cloud Router redundant interface first
resource "google_compute_router_interface" "cr_redundant_interface" {
  for_each           = var.regional_config
  project            = var.project
  name               = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-int-redundant"
  region             = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].region
  router             = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork         = google_compute_subnetwork.edge_vpc_subnets[each.key].self_link
  private_ip_address = google_compute_address.cr_redundant_addr[each.key].address
}

# Create Cloud Router primary interface, note it references the redundant interface
resource "google_compute_router_interface" "cr_primary_interface" {
  for_each            = var.regional_config
  project             = var.project
  name                = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-int-primary"
  region              = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].region
  router              = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork          = google_compute_subnetwork.edge_vpc_subnets[each.key].self_link
  private_ip_address  = google_compute_address.cr_primary_addr[each.key].address
  redundant_interface = google_compute_router_interface.cr_redundant_interface[each.key].name
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

# Create Aviatrix Spoke VPC and Gateways, then attach to correponding transits
module "mc-spoke" {
  for_each   = var.regional_config
  source     = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version    = "1.5.0" # Lookup module version to controller version mapping: https://registry.terraform.io/modules/terraform-aviatrix-modules/mc-spoke/aviatrix/latest
  cloud      = "GCP"
  region     = each.key
  cidr       = each.value.aviatrix_spoke_vpc_subnet_ip_cidr_range
  account    = var.account
  name       = each.value.aviatrix_spoke_vpc_name
  gw_name    = each.value.aviatrix_spoke_gateway_name
  transit_gw = module.mc-transit[each.key].transit_gateway.gw_name
  ha_gw      = true
}


# Create test VM instances
resource "google_compute_instance" "vm_public" {
  for_each     = var.regional_config
  project      = var.project
  name         = "gcp-vm-public-${each.key}"
  machine_type = "n1-standard-1"
  zone         = module.mc-spoke[each.key].spoke_gateway.vpc_reg

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network    = module.mc-spoke[each.key].vpc.id
    subnetwork = "https://www.googleapis.com/compute/v1/projects/${var.project}/regions/${each.key}/subnetworks/${module.mc-spoke[each.key].vpc.subnets[0].name}"
    access_config {} //ephemeral IP
  }

  tags = ["allow-ssh", "allow-icmp"]

  metadata = {
    startup-script = <<-EOF
#!/bin/bash
sudo apt update
sudo apt install -y mysql-client
  EOF
  }

}

# Firewall rule to allow ssh
resource "google_compute_firewall" "allow_ssh" {
  for_each = var.regional_config
  project  = var.project
  name     = "${module.mc-spoke[each.key].vpc.subnets[0].name}-allow-ssh"
  network  = module.mc-spoke[each.key].vpc.id


  allow {
    protocol = "tcp"
    ports    = ["22"]
  }


  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-ssh"]
}

resource "google_compute_firewall" "allow_icmp" {
  for_each = var.regional_config
  project  = var.project
  name     = "${module.mc-spoke[each.key].vpc.subnets[0].name}-allow-icmp"
  network  = module.mc-spoke[each.key].vpc.id


  allow {
    protocol = "icmp"
  }


  source_ranges = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  target_tags   = ["allow-icmp"]
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
      ip_address      = module.mc-transit[each.key].transit_gateway.bgp_lan_ip_list[0]
    }
    instances {
      virtual_machine = "https://www.googleapis.com/compute/v1/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.ha_zone}/instances/${module.mc-transit[each.key].transit_gateway.ha_gw_name}"
      ip_address      = module.mc-transit[each.key].transit_gateway.ha_bgp_lan_ip_list[0]
    }
    site_to_site_data_transfer = true
  }
}


# Configure four Cloud Router BGP peers between with Cloud Router primary/redundant interfaces with Aviatrix Primary/HA Transit Gateways in NCC
resource "google_compute_router_peer" "cr_primary_int_peer_with_primary_gw" {
  for_each                  = var.regional_config
  project                   = var.project
  name                      = "cr-pri-int-peer-${module.mc-transit[each.key].transit_gateway.gw_name}"
  router                    = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  region                    = each.key
  peer_ip_address           = module.mc-transit[each.key].transit_gateway.bgp_lan_ip_list[0]
  peer_asn                  = module.mc-transit[each.key].transit_gateway.local_as_number
  interface                 = google_compute_router_interface.cr_primary_interface[each.key].name
  router_appliance_instance = "/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.vpc_reg}/instances/${module.mc-transit[each.key].transit_gateway.gw_name}"
}

resource "google_compute_router_peer" "cr_primary_int_peer_with_ha_gw" {
  for_each                  = var.regional_config
  project                   = var.project
  name                      = "cr-pri-int-peer-${module.mc-transit[each.key].transit_gateway.ha_gw_name}"
  router                    = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  region                    = each.key
  peer_ip_address           = module.mc-transit[each.key].transit_gateway.ha_bgp_lan_ip_list[0]
  peer_asn                  = module.mc-transit[each.key].transit_gateway.local_as_number
  interface                 = google_compute_router_interface.cr_primary_interface[each.key].name
  router_appliance_instance = "/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.ha_zone}/instances/${module.mc-transit[each.key].transit_gateway.ha_gw_name}"
}

resource "google_compute_router_peer" "cr_redundant_int_peer_with_primary_gw" {
  for_each                  = var.regional_config
  project                   = var.project
  name                      = "cr-red-int-peer-${module.mc-transit[each.key].transit_gateway.gw_name}"
  router                    = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  region                    = each.key
  peer_ip_address           = module.mc-transit[each.key].transit_gateway.bgp_lan_ip_list[0]
  peer_asn                  = module.mc-transit[each.key].transit_gateway.local_as_number
  interface                 = google_compute_router_interface.cr_redundant_interface[each.key].name
  router_appliance_instance = "/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.vpc_reg}/instances/${module.mc-transit[each.key].transit_gateway.gw_name}"
}

resource "google_compute_router_peer" "cr_redundant_int_peer_with_ha_gw" {
  for_each                  = var.regional_config
  project                   = var.project
  name                      = "cr-red-int-peer-${module.mc-transit[each.key].transit_gateway.ha_gw_name}"
  router                    = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  region                    = each.key
  peer_ip_address           = module.mc-transit[each.key].transit_gateway.ha_bgp_lan_ip_list[0]
  peer_asn                  = module.mc-transit[each.key].transit_gateway.local_as_number
  interface                 = google_compute_router_interface.cr_redundant_interface[each.key].name
  router_appliance_instance = "/projects/${var.project}/zones/${module.mc-transit[each.key].transit_gateway.ha_zone}/instances/${module.mc-transit[each.key].transit_gateway.ha_gw_name}"
}


# Create an Aviatrix Transit External Device Connection to establish BGP over LAN towards Cloud Router
resource "aviatrix_transit_external_device_conn" "bgp_over_lan" {
  for_each                  = var.regional_config
  vpc_id                    = module.mc-transit[each.key].transit_gateway.vpc_id
  connection_name           = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  connection_type           = "bgp"
  tunnel_protocol           = "LAN"
  ha_enabled                = true
  enable_bgp_lan_activemesh = true

  gw_name = module.mc-transit[each.key].transit_gateway.gw_name


  bgp_local_as_num  = module.mc-transit[each.key].transit_gateway.local_as_number
  bgp_remote_as_num = each.value.cr_asn
  remote_lan_ip     = google_compute_router_interface.cr_primary_interface[each.key].private_ip_address
  local_lan_ip      = module.mc-transit[each.key].transit_gateway.bgp_lan_ip_list[0]

  backup_bgp_remote_as_num = each.value.cr_asn
  backup_remote_lan_ip     = google_compute_router_interface.cr_redundant_interface[each.key].private_ip_address
  backup_local_lan_ip      = module.mc-transit[each.key].transit_gateway.ha_bgp_lan_ip_list[0]
}
