variable "folder_id" {
  description = "Folder ID for Kubernetes resources"
  type        = string
}

variable "cluster_name" {
  description = "Managed Kubernetes cluster name"
  type        = string
}

variable "cluster_description" {
  description = "Managed Kubernetes cluster description"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "release_channel" {
  description = "Managed Kubernetes release channel"
  type        = string
}

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "master_locations" {
  description = "Locations for the regional Kubernetes master"
  type = map(object({
    zone      = string
    subnet_id = string
  }))
}

variable "master_security_group_ids" {
  description = "Security group IDs for the Kubernetes master"
  type        = list(string)
}

variable "service_account_id" {
  description = "Cluster service account ID"
  type        = string
}

variable "node_service_account_id" {
  description = "Node service account ID"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID"
  type        = string
}

variable "cluster_ipv4_range" {
  description = "CIDR for pod IPs"
  type        = string
}

variable "service_ipv4_range" {
  description = "CIDR for service IPs"
  type        = string
}

variable "master_public_ip" {
  description = "Expose public endpoint for the master"
  type        = bool
}

variable "create_node_group" {
  description = "Create node group together with the cluster"
  type        = bool
}

variable "node_group_name" {
  description = "Node group name"
  type        = string
}

variable "node_group_description" {
  description = "Node group description"
  type        = string
}

variable "node_count" {
  description = "Node count in fixed scale policy"
  type        = number
}

variable "node_platform_id" {
  description = "Platform ID for worker nodes"
  type        = string
}

variable "node_cores" {
  description = "CPU cores per node"
  type        = number
}

variable "node_memory" {
  description = "Memory in GB per node"
  type        = number
}

variable "node_core_fraction" {
  description = "Guaranteed CPU share for nodes"
  type        = number
}

variable "node_disk_type" {
  description = "Boot disk type"
  type        = string
}

variable "node_disk_size" {
  description = "Boot disk size in GB"
  type        = number
}

variable "node_preemptible" {
  description = "Whether nodes are preemptible"
  type        = bool
}

variable "node_subnet_ids" {
  description = "Subnets for node network interfaces"
  type        = map(string)
}

variable "node_locations" {
  description = "Node allocation locations"
  type = map(object({
    zone      = string
    subnet_id = string
  }))
}

variable "node_security_group_ids" {
  description = "Security groups for node network interfaces"
  type        = list(string)
}
