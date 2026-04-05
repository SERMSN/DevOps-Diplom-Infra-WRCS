variable "folder_id" {
  description = "Folder ID for security groups"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for security group names"
  type        = string
}

variable "cluster_ipv4_range" {
  description = "Cluster pod CIDR"
  type        = string
}

variable "service_ipv4_range" {
  description = "Cluster service CIDR"
  type        = string
}

variable "kubernetes_api_allowed_cidrs" {
  description = "CIDR blocks allowed to access the Kubernetes API"
  type        = list(string)
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to access worker nodes via SSH"
  type        = list(string)
}
