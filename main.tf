# Create Edge VPC
resource "google_compute_network" "edge_vpc" {
  project                 = var.project
  name                    = var.edge_vpc_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# Create subnets for Edge VPC, each subnet map to a region.
resource "google_compute_subnetwork" "edge_vpc_subnets" {
  for_each      = var.edge_vpc_subnets
  project       = var.project
  region        = each.value.region
  name          = each.key
  ip_cidr_range = each.value.ip_cidr_range
  network       = google_compute_network.edge_vpc.id
}

# Create cloud routers per subnet per region.
resource "google_compute_router" "edge_vpc_subnet_cloud_routers" {
  for_each = var.edge_vpc_subnets
  project  = var.project
  region   = each.value.region
  name     = "${each.key}-cr"
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
  for_each           = var.edge_vpc_subnets
  project            = var.project
  region             = each.value.region
  name               = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-1"
  router             = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork         = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  private_ip_address = cidrhost(each.value.ip_cidr_range, (pow(2, (32 - tonumber(split("/", each.value.ip_cidr_range)[1]))) - 4))
}
# Provsion the second interface of CR
resource "google_compute_router_interface" "cr_interface_2" {
  for_each           = var.edge_vpc_subnets
  project            = var.project
  region             = each.value.region
  name               = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-2"
  router             = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork         = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  private_ip_address = cidrhost(each.value.ip_cidr_range, (pow(2, (32 - tonumber(split("/", each.value.ip_cidr_range)[1]))) - 3))
}


# Private Service Connection IP Range allocations
resource "google_compute_global_address" "private_service_connection_ip_range" {
  for_each      = var.edge_vpc_subnets
  project       = var.project
  name          = "${var.edge_vpc_name}-psc-${each.value.region}"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = google_compute_network.edge_vpc.id
  ip_version    = "IPV4"
  address       = split("/", each.value.private_service_connection_ip_range)[0]
  prefix_length = tonumber(split("/", each.value.private_service_connection_ip_range)[1])
  # address       = each.value.private_service_connection_ip_range
}

# Equivlent to VPC -> Private Service Connection -> Private Connections to Services -> Select Google Cloud Platform as Connected service producer, and check allocated IP ranges.
resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.edge_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for k,v in google_compute_global_address.private_service_connection_ip_range: v.name]
}

# Make sure the VPC peering with the Private Service Connection will export custom route
resource "google_compute_network_peering_routes_config" "private_service_access_generic" {
  

  project = var.project
  peering = google_service_networking_connection.default.peering
  network = google_compute_network.edge_vpc.name

  import_custom_routes = false
  export_custom_routes = true # We change this from the default to export our custom routes

}


