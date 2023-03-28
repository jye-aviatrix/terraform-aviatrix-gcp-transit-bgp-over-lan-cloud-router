variable "project" {
  description = "Provide GCP project name"
  type        = string
}

variable "edge_vpc_name" {
  description = "Provide Edge VPC name"
  type        = string
}

variable "regional_config" {
  description = "Provide regional configuration"
  type        = map(any)
  default = {
    us-central1 = { # key name: region where the Global Service is deployed. If Cloud SQL will be deployed in us-centra1 and us-west2, then you will need to list both in the map

      edge_vpc_subnet_ip_cidr_range = "10.0.2.0/24" # Provide edge VPC subnet CIDR range for the first region
      cr_asn                        = 65201         # Each Cloud Router need it's unique ASN number

      aviatrix_transit_vpc_subnet_ip_cidr_range = "10.16.1.0/24" # Provide Aviatrix Transit VPC subnet CIDR range
      avx_transit_asn                           = 65301

      # must provide proper IPv4 CIDR notatiion in the format of nn.nn.nn.nn/nn
      private_service_connection_ip_range = "10.0.100.0/24" # This is the range of IP allocated to Gloabl Services such as Cloud SQL. https://cloud.google.com/vpc/docs/configure-private-services-access?#allocating-range. Specify the IP range for this region only.
    }
    us-west2 = {
      edge_vpc_subnet_ip_cidr_range = "10.0.3.0/24" # Provide edge VPC subnet CIDR range for the second region
      cr_asn                        = 65202

      aviatrix_transit_vpc_subnet_ip_cidr_range = "10.16.2.0/24" # Provide Aviatrix Transit VPC subnet CIDR range
      avx_transit_asn                           = 65302

      private_service_connection_ip_range = "10.0.102.0/24"
    }
  }
}
