variable "folder_id" {
  description = "Folder ID for KMS resources"
  type        = string
}

variable "key_name" {
  description = "KMS key name"
  type        = string
}

variable "description" {
  description = "KMS key description"
  type        = string
  default     = ""
}
