output "key_id" {
  description = "KMS key ID"
  value       = yandex_kms_symmetric_key.this.id
}
