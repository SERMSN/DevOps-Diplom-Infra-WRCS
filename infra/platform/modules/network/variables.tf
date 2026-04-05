variable "folder_id" {
  description = "Folder ID for network resources"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnets" {
  description = "Subnets to create"
  type = map(object({
    zone = string
    cidr = string
  }))
}
