resource "yandex_container_registry" "this" {
  folder_id = var.folder_id
  name      = var.name
}
