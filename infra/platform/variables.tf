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

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "netology-diplom-network"
}

variable "subnets" {
  description = "Subnets for the Kubernetes cluster"
  type = map(object({
    zone = string
    cidr = string
  }))
  default = {
    subnet-a = {
      zone = "ru-central1-a"
      cidr = "10.10.1.0/24"
    }
    subnet-b = {
      zone = "ru-central1-b"
      cidr = "10.10.2.0/24"
    }
    subnet-d = {
      zone = "ru-central1-d"
      cidr = "10.10.3.0/24"
    }
  }
}

variable "registry_name" {
  description = "Container Registry name"
  type        = string
  default     = "netology-diplom-registry"
}

variable "kms_key_name" {
  description = "KMS key name for Kubernetes secret encryption"
  type        = string
  default     = "netology-diplom-kms-key"
}

variable "cluster_name" {
  description = "Managed Kubernetes cluster name"
  type        = string
  default     = "netology-diplom-cluster"
}

variable "cluster_description" {
  description = "Managed Kubernetes cluster description"
  type        = string
  default     = "Managed Kubernetes cluster for Netology diploma WRCS-TEST"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "release_channel" {
  description = "Managed Kubernetes release channel"
  type        = string
  default     = "STABLE"
}

variable "node_group_name" {
  description = "Kubernetes node group name"
  type        = string
  default     = "netology-diplom-nodes"
}

variable "node_group_description" {
  description = "Kubernetes node group description"
  type        = string
  default     = "Preemptible worker nodes for Netology diploma"
}

variable "create_node_group" {
  description = "Create Kubernetes node group in this apply"
  type        = bool
  default     = false
}

variable "node_count" {
  description = "Number of nodes in the fixed node group"
  type        = number
  default     = 3
}

variable "node_platform_id" {
  description = "Platform ID for Kubernetes worker nodes"
  type        = string
  default     = "standard-v3"
}

variable "node_cores" {
  description = "CPU cores per Kubernetes worker node"
  type        = number
  default     = 2
}

variable "node_memory" {
  description = "Memory in GB per Kubernetes worker node"
  type        = number
  default     = 4
}

variable "node_core_fraction" {
  description = "Guaranteed CPU share for worker nodes"
  type        = number
  default     = 20
}

variable "node_disk_type" {
  description = "Boot disk type for worker nodes"
  type        = string
  default     = "network-hdd"
}

variable "node_disk_size" {
  description = "Boot disk size in GB for worker nodes"
  type        = number
  default     = 64
}

variable "node_preemptible" {
  description = "Use preemptible instances for worker nodes"
  type        = bool
  default     = true
}

variable "cluster_ipv4_range" {
  description = "CIDR for pod addresses in the cluster"
  type        = string
  default     = "10.200.0.0/16"
}

variable "service_ipv4_range" {
  description = "CIDR for service addresses in the cluster"
  type        = string
  default     = "10.96.0.0/16"
}

variable "master_public_ip" {
  description = "Expose public IPv4 endpoint for Kubernetes master"
  type        = bool
  default     = true
}

variable "kubernetes_api_allowed_cidrs" {
  description = "CIDR blocks allowed to access the Kubernetes API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to connect to worker nodes over SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
