variable "folder_id" {
  description = "Folder ID for service accounts"
  type        = string
}

variable "service_account_name" {
  description = "Name of the service account used by the cluster and nodes"
  type        = string
}

variable "service_account_roles" {
  description = "Folder roles assigned to the service account"
  type        = list(string)
}
