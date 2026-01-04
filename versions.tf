terraform {
  required_version = ">= 1.5.0"
  required_providers {
    system = {
      source  = "neuspaces/system"
      version = "~> 0.5.0"
    }
  }
}