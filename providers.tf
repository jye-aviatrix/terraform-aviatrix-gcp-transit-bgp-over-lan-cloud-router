provider "google" {
}

terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
      version = "~>3.0.0" # Lookup Aviatrix Provider: Release Compatibility Chart for the version that works for your controller version https://registry.terraform.io/providers/AviatrixSystems/aviatrix/latest/docs/guides/release-compatibility
    }
  }
}