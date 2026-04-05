resource "yandex_iam_service_account" "this" {
  folder_id   = var.folder_id
  name        = var.service_account_name
  description = "Service account for Managed Kubernetes cluster and nodes"
}

resource "yandex_resourcemanager_folder_iam_member" "roles" {
  for_each  = toset(var.service_account_roles)
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.this.id}"
}
