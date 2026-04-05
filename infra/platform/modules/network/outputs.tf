output "network_id" {
  description = "VPC network ID"
  value       = yandex_vpc_network.this.id
}

output "subnet_ids" {
  description = "Created subnet IDs"
  value       = { for name, subnet in yandex_vpc_subnet.this : name => subnet.id }
}

output "subnet_locations" {
  description = "Subnet locations mapped by subnet name"
  value = {
    for name, subnet in yandex_vpc_subnet.this : name => {
      zone      = subnet.zone
      subnet_id = subnet.id
    }
  }
}
