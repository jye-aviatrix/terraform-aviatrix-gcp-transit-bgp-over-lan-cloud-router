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
        ip_cidr_range = "10.0.2.0/24"
        region = "us-central1"
        cr_asn = 65201
        advertised_ip_ranges = [
            "10.0.100.0/24", # must provide proper IPv4 CIDR notatiion in the format of nn.nn.nn.nn/nn
            "10.0.101.0/24"
        ]
    }
    edge-us-west2 = {
        ip_cidr_range = "10.0.3.0/24"
        region = "us-west2"
        cr_asn = 65202
        advertised_ip_ranges = [
            "10.0.102.0/24",
            "10.0.103.0/24"
        ]
    }
  }
}
