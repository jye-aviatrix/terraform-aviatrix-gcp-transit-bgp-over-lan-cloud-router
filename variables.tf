variable "project" {
  description = "Provide GCP project name"
  type = string
}

variable "edge_vpc_name" {
  description = "Provide Edge VPC name"
  type = string
}

variable "edge_vpc_subnets" {
  description = "Provide subnets for Edge VPCs"
  type = map
  default = {
    edge-us-central1 = {  # key name: eg edge-us-central1 will become subnet name
        ip_cidr_range = "10.0.2.0/24"  # Provide edge VPC subnet CIDR range for the first region
        region = "us-central1" # Each subnet should be in the region mapping the gloabl service region, such as Cloud SQL.
        cr_asn = 65201  # Each Cloud Router need it's unique ASN number

        # must provide proper IPv4 CIDR notatiion in the format of nn.nn.nn.nn/nn
        private_service_connection_ip_range = "10.0.100.0/24" # This is the range of IP allocated to Gloabl Services such as Cloud SQL. https://cloud.google.com/vpc/docs/configure-private-services-access?#allocating-range. Specify the IP range for this region only.
    }
    edge-us-west2 = {
        ip_cidr_range = "10.0.3.0/24" # Provide edge VPC subnet CIDR range for the second region
        region = "us-west2"
        cr_asn = 65202
        private_service_connection_ip_range = "10.0.102.0/24"
    }
  }
}
