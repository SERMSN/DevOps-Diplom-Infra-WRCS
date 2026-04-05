output "cluster_id" {
  description = "Managed Kubernetes cluster ID"
  value       = yandex_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Managed Kubernetes cluster name"
  value       = yandex_kubernetes_cluster.this.name
}

output "cluster_external_v4_endpoint" {
  description = "Public Kubernetes API endpoint"
  value       = yandex_kubernetes_cluster.this.master[0].external_v4_endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = yandex_kubernetes_cluster.this.master[0].cluster_ca_certificate
}

output "node_group_id" {
  description = "Managed Kubernetes node group ID"
  value       = var.create_node_group ? yandex_kubernetes_node_group.this[0].id : null
}
