# terraform-aviatrix-gcp-transit-bgp-over-lan-cloud-router
- This terraform code will deploy two Aviatrix Spoke and Transits. 
- Each Spoke and Transit VPC would only have one subnet in a single region
- A psc-global-vpc will be deployed, within this VPC, subnets will be created in different regions align with cloud SQL instance region
- Two IP ranges 10.192.0.0/20 and 10.192.16.0 will be allocated on psc-global-vpc to be consumed by Cloud SQL. Each IP range will be allocated to Cloud SQL instance in different regions.
- Aviatrix Transit forms full mesh BGP over LAN connection with GCP Cloud Routers in the same region within psc-global-vpc
- Cloud Router perform custom advertisement of the allocated IP range match SQL instance in the same region towards corresponding Aviatrix Transit
- The private service connection export routes received by Cloud Router to GCP managed VPC for Cloud SQL
- A primary and a read replica of Cloud SQL will be deployed aligned with the region of Aviatrix Transit.
- spoke in us-central1 will only be able to talk to primary SQL instance in us-central1
- spoke in us-west2 will only be able to talk to read replica SQL instance in us-west2
- To allow cross communication, either peer the two Aviatrix Transit, or advertise both IP ranges in both Cloud Routers
- To perform traffic inspection, it's better treat transit in this diagram as spoke, then deploy additional Aviatrix Transit FireNet with Multi-tier transit enabled. Connect both spoke and existing transit to MTT Transit Firenet

Blog post: https://cloudlearning365.com/?p=1291

## Architecture diagram
![](https://raw.githubusercontent.com/jye-aviatrix/terraform-aviatrix-gcp-transit-bgp-over-lan-cloud-router/master/GCP%20Cloud-SQL-Private-Access-with-Aviatrix-Transit.png)

## Running environment
```
Terraform v1.3.7
on linux_amd64
+ provider registry.terraform.io/aviatrixsystems/aviatrix v3.0.3
+ provider registry.terraform.io/hashicorp/google v4.59.0
+ provider registry.terraform.io/hashicorp/random v3.4.3

Aviatrix Controller: 7.0.1383
```


## Cost
```
 Name                                                        Monthly Qty  Unit            Monthly Cost

 google_compute_instance.vm_public["us-central1"]
 ├─ Instance usage (Linux/UNIX, on-demand, n1-standard-1)            730  hours                 $24.27
 └─ Standard provisioned storage (pd-standard)                        10  GB                     $0.40

 google_compute_instance.vm_public["us-west2"]
 ├─ Instance usage (Linux/UNIX, on-demand, n1-standard-1)            730  hours                 $24.27
 └─ Standard provisioned storage (pd-standard)                        10  GB                     $0.40

 google_service_networking_connection.psc_generic
 └─ Network egress
    ├─ Traffic within the same region                      Monthly cost depends on usage: $0.01 per GB
    ├─ Traffic within the US or Canada                     Monthly cost depends on usage: $0.01 per GB
    ├─ Traffic within Europe                               Monthly cost depends on usage: $0.02 per GB
    ├─ Traffic within Asia                                 Monthly cost depends on usage: $0.05 per GB
    ├─ Traffic within South America                        Monthly cost depends on usage: $0.08 per GB
    ├─ Traffic to/from Indonesia and Oceania               Monthly cost depends on usage: $0.15 per GB
    └─ Traffic between continents (excludes Oceania)       Monthly cost depends on usage: $0.08 per GB

 google_sql_database_instance.mysql_primary
 ├─ SQL instance (db-n1-standard-1, zonal)                           730  hours                $789.28
 ├─ Storage (SSD, zonal)                                              10  GB                     $1.70
 └─ Backups                                                Monthly cost depends on usage: $0.08 per GB

 google_sql_database_instance.mysql_read_replica
 ├─ SQL instance (db-n1-standard-1, zonal)                           730  hours                $789.28
 ├─ Storage (SSD, zonal)                                              10  GB                     $1.70
 └─ Backups                                                Monthly cost depends on usage: $0.08 per GB

 OVERALL TOTAL                                                                               $1,631.30
 ```