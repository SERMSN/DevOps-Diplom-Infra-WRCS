/*
Fill remote backend settings after bootstrap is applied.
Example:

terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket                      = "replace-me"
    key                         = "infrastructure/terraform.tfstate"
    region                      = "ru-central1"
    access_key                  = "replace-me"
    secret_key                  = "replace-me"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
*/
