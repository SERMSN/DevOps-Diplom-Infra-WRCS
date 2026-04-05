output "registry_id" {
  description = "Container Registry ID"
  value       = yandex_container_registry.this.id
}

output "registry_name" {
  description = "Container Registry name"
  value       = yandex_container_registry.this.name
}
