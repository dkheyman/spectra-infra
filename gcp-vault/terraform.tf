provider "google-beta" {
  region = "${var.region}"
}

terraform {
  backend "gcs" {
    bucket  = "spectra-iac-backend"
    prefix  = "prod/vault"
  }
}