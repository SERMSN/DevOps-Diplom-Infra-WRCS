resource "yandex_vpc_network" "this" {
  folder_id = var.folder_id
  name      = var.network_name
}

resource "yandex_vpc_subnet" "this" {
  for_each       = var.subnets
  folder_id      = var.folder_id
  name           = each.key
  zone           = each.value.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [each.value.cidr]
}
