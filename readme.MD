# terraform-aviatrix-gcp-transit-bgp-over-lan-cloud-router

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