terraform {
  required_version = ">= 1.5.0"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = ">= 3.8.0"
    }
  }
}
