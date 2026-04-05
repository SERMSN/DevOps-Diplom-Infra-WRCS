output "cluster_nodegroup_traffic_security_group_id" {
  description = "Managed Kubernetes shared service traffic security group ID"
  value       = yandex_vpc_security_group.cluster_nodegroup_traffic.id
}

output "public_services_security_group_id" {
  description = "Managed Kubernetes public services security group ID"
  value       = yandex_vpc_security_group.public_services.id
}

output "kubernetes_api_security_group_id" {
  description = "Managed Kubernetes API security group ID"
  value       = yandex_vpc_security_group.kubernetes_api.id
}

output "ssh_security_group_id" {
  description = "Managed Kubernetes SSH security group ID"
  value       = yandex_vpc_security_group.ssh.id
}
