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
    advertised_groups = [""]
    dynamic "advertised_ip_ranges" {
      for_each = each.value.advertised_ip_ranges
      content {
        range = advertised_ip_ranges.value
      }
    }
  }
  depends_on = [
    google_compute_subnetwork.edge_vpc_subnets
  ]
}

# Provsion the first interface of CR
resource "google_compute_router_interface" "cr_interface_1" {
  for_each = var.edge_vpc_subnets
  project  = var.project
  region   = each.value.region
  name       = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-1"
  router     = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  private_ip_address = cidrhost(each.value.ip_cidr_range, (pow(2,(32-tonumber(split("/",each.value.ip_cidr_range)[1])))-4))
}
# Provsion the second interface of CR
resource "google_compute_router_interface" "cr_interface_2" {
  for_each = var.edge_vpc_subnets
  project  = var.project
  region   = each.value.region
  name       = "${google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name}-2"
  router     = google_compute_router.edge_vpc_subnet_cloud_routers[each.key].name
  subnetwork = google_compute_subnetwork.edge_vpc_subnets[each.key].id
  private_ip_address = cidrhost(each.value.ip_cidr_range, (pow(2,(32-tonumber(split("/",each.value.ip_cidr_range)[1])))-3))
}

