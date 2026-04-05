output "terraform_service_account_id" {
  description = "Terraform service account ID"
  value       = yandex_iam_service_account.terraform.id
}

output "terraform_service_account_name" {
  description = "Terraform service account name"
  value       = yandex_iam_service_account.terraform.name
}

output "tf_state_bucket_name" {
  description = "Remote state bucket name"
  value       = yandex_storage_bucket.tf_state.bucket
}

output "tf_state_backend_key" {
  description = "Recommended object key for the infrastructure state"
  value       = var.tf_state_object_key
}

output "tf_state_access_key" {
  description = "Access key for the S3 backend"
  value       = yandex_iam_service_account_static_access_key.terraform.access_key
  sensitive   = true
}

output "tf_state_secret_key" {
  description = "Secret key for the S3 backend"
  value       = yandex_iam_service_account_static_access_key.terraform.secret_key
  sensitive   = true
}

output "backend_tf_config" {
  description = "Backend configuration snippet for terraform/infrastructure/backend.tf"
  sensitive   = true
  value       = <<-EOT
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket                      = "${yandex_storage_bucket.tf_state.bucket}"
    key                         = "${var.tf_state_object_key}"
    region                      = "ru-central1"
    access_key                  = "${yandex_iam_service_account_static_access_key.terraform.access_key}"
    secret_key                  = "${yandex_iam_service_account_static_access_key.terraform.secret_key}"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
EOT
}
