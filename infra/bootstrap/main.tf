resource "yandex_iam_service_account" "terraform" {
  name        = var.tf_service_account_name
  description = "Service account used by Terraform for diploma infrastructure"
}

resource "yandex_resourcemanager_folder_iam_member" "terraform_roles" {
  for_each  = toset(var.tf_service_account_roles)
  folder_id = var.yc_folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.terraform.id}"
}

resource "yandex_storage_bucket" "tf_state" {
  bucket        = var.tf_state_bucket_name
  folder_id     = var.yc_folder_id
  force_destroy = true

  versioning {
    enabled = true
  }

  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.terraform_roles]
}

resource "yandex_iam_service_account_static_access_key" "terraform" {
  service_account_id = yandex_iam_service_account.terraform.id
  description        = "Static access key for Terraform S3 backend"
}
