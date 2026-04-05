resource "yandex_kms_symmetric_key" "this" {
  folder_id         = var.folder_id
  name              = var.key_name
  description       = var.description
  default_algorithm = "AES_128"
  rotation_period   = "8760h"
}
