resource "yandex_kubernetes_cluster" "this" {
  folder_id               = var.folder_id
  name                    = var.cluster_name
  description             = var.cluster_description
  network_id              = var.network_id
  service_account_id      = var.service_account_id
  node_service_account_id = var.node_service_account_id
  release_channel         = var.release_channel
  network_policy_provider = "CALICO"
  cluster_ipv4_range      = var.cluster_ipv4_range
  service_ipv4_range      = var.service_ipv4_range

  master {
    version = var.cluster_version

    regional {
      region = "ru-central1"

      dynamic "location" {
        for_each = var.master_locations
        content {
          zone      = location.value.zone
          subnet_id = location.value.subnet_id
        }
      }
    }

    public_ip          = var.master_public_ip
    security_group_ids = var.master_security_group_ids

    maintenance_policy {
      auto_upgrade = true

      maintenance_window {
        day        = "monday"
        start_time = "03:00"
        duration   = "3h"
      }
    }
  }

  kms_provider {
    key_id = var.kms_key_id
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }
}

resource "yandex_kubernetes_node_group" "this" {
  count       = var.create_node_group ? 1 : 0
  cluster_id  = yandex_kubernetes_cluster.this.id
  name        = var.node_group_name
  description = var.node_group_description
  version     = var.cluster_version

  instance_template {
    platform_id = var.node_platform_id

    network_interface {
      nat                = true
      subnet_ids         = values(var.node_subnet_ids)
      security_group_ids = var.node_security_group_ids
    }

    resources {
      cores         = var.node_cores
      memory        = var.node_memory
      core_fraction = var.node_core_fraction
    }

    boot_disk {
      type = var.node_disk_type
      size = var.node_disk_size
    }

    scheduling_policy {
      preemptible = var.node_preemptible
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  dynamic "allocation_policy" {
    for_each = length(var.node_locations) > 0 ? [1] : []
    content {
      dynamic "location" {
        for_each = var.node_locations
        content {
          zone = location.value.zone
        }
      }
    }
  }

  deploy_policy {
    max_expansion   = 1
    max_unavailable = 1
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
  }

  timeouts {
    create = "90m"
    update = "90m"
    delete = "60m"
  }
}
