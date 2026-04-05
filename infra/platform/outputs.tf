output "network_id" {
  description = "VPC network ID"
  value       = module.network.network_id
}

output "subnet_ids" {
  description = "Subnet IDs for the cluster"
  value       = module.network.subnet_ids
}

output "registry_id" {
  description = "Container Registry ID"
  value       = module.registry.registry_id
}

output "registry_name" {
  description = "Container Registry name"
  value       = module.registry.registry_name
}

output "kms_key_id" {
  description = "KMS key ID used for Kubernetes secrets"
  value       = module.kms.key_id
}

output "kubernetes_cluster_id" {
  description = "Managed Kubernetes cluster ID"
  value       = module.kubernetes.cluster_id
}

output "kubernetes_cluster_name" {
  description = "Managed Kubernetes cluster name"
  value       = module.kubernetes.cluster_name
}

output "kubernetes_cluster_external_endpoint" {
  description = "Public Kubernetes API endpoint"
  value       = module.kubernetes.cluster_external_v4_endpoint
}

output "kubernetes_cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = module.kubernetes.cluster_ca_certificate
  sensitive   = true
}

output "kubernetes_node_group_id" {
  description = "Managed Kubernetes node group ID"
  value       = module.kubernetes.node_group_id
}

output "get_kubeconfig_command" {
  description = "Command to fetch kubeconfig for the cluster"
  value       = "yc managed-kubernetes cluster get-credentials --id ${module.kubernetes.cluster_id} --external"
}
