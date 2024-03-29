variable "project" {
  description = "Provide GCP project name"
  type        = string
}

variable "psc_vpc_name" {
  description = "Provide Private Service Connection Global VPC name, note this VPC will have subnets from multiple regions, mapping to Global Cloud Service regions, such as Cloud SQL instance regions"
  type        = string
}

variable "regional_config" {
  description = "Provide regional configuration"
  type        = map(any)
  default = {
    us-central1 = { # key name: region where the Global Service are deployed. If Cloud SQL will be deployed in us-centra1 and us-west2, then you will need to list both in the map

      psc_vpc_subnet_ip_cidr_range = "10.0.1.0/24" # Provide Private Service Connection VPC subnet CIDR range for the first region
      cr_asn                        = 65201         # Each Cloud Router need it's unique ASN number

      aviatrix_transit_vpc_name                 = "gcp-transit-us-central1" # Provide Aviatrix Transit VPC name, note: Aviatrix Transit is regional.
      aviatrix_transit_vpc_subnet_ip_cidr_range = "10.16.1.0/24"            # Provide Aviatrix Transit VPC subnet CIDR range
      aviatrix_transit_gateway_name             = "gcp-transit-us-central1-gw"
      avx_transit_asn                           = 65301

      aviatrix_spoke_vpc_name = "gcp-spoke-us-central1"
      aviatrix_spoke_vpc_subnet_ip_cidr_range = "10.128.1.0/24" 
      aviatrix_spoke_gateway_name = "gcp-spoke-us-central1-gw"

      # must provide proper IPv4 CIDR notatiion in the format of nn.nn.nn.nn/nn
      private_service_connection_ip_range = "10.192.0.0/20" # This is the range of IP allocated to Gloabl Services such as Cloud SQL. https://cloud.google.com/vpc/docs/configure-private-services-access?#allocating-range. Specify the IP range for this region only.
    }
    us-west2 = {
      psc_vpc_subnet_ip_cidr_range = "10.0.2.0/24" # Provide Private Service Connection VPC subnet CIDR range for the second region
      cr_asn                        = 65202

      aviatrix_transit_vpc_name                 = "gcp-transit-us-west2"
      aviatrix_transit_vpc_subnet_ip_cidr_range = "10.16.2.0/24" # Provide Aviatrix Transit VPC subnet CIDR range
      aviatrix_transit_gateway_name             = "gcp-transit-us-west2-gw"
      avx_transit_asn                           = 65302

      aviatrix_spoke_vpc_name = "gcp-spoke-us-west2"
      aviatrix_spoke_vpc_subnet_ip_cidr_range = "10.128.2.0/24" 
      aviatrix_spoke_gateway_name = "gcp-spoke-us-west2-gw"

      private_service_connection_ip_range = "10.192.16.0/20"
    }
  }
}


variable "account" {
  description = "Provide Aviatrix GCP Access Account name"
  type        = string
}
