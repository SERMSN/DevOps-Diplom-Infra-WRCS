variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "yc_zone" {
  description = "Default Yandex Cloud zone"
  type        = string
  default     = "ru-central1-a"
}

variable "tf_state_bucket_name" {
  description = "S3 bucket name for Terraform backend state"
  type        = string
}

variable "tf_service_account_name" {
  description = "Service account name for Terraform"
  type        = string
  default     = "tf-sa"
}

variable "tf_state_object_key" {
  description = "Initial object key prefix for the Terraform remote state"
  type        = string
  default     = "infrastructure/terraform.tfstate"
}

variable "tf_service_account_roles" {
  description = "IAM roles assigned to the Terraform service account in the folder"
  type        = list(string)
  default = [
    "editor",
    "storage.admin",
    "container-registry.admin",
    "k8s.admin",
    "load-balancer.admin",
    "vpc.admin",
    "kms.admin"
  ]
}
