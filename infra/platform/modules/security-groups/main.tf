resource "yandex_vpc_security_group" "cluster_nodegroup_traffic" {
  folder_id   = var.folder_id
  network_id  = var.network_id
  name        = "${var.name_prefix}-cluster-nodegroup-traffic"
  description = "Service traffic rules for the Managed Kubernetes cluster and node groups"

  ingress {
    description       = "Network load balancer health checks"
    from_port         = 0
    to_port           = 65535
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description       = "Traffic between master and nodes and between nodes"
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  ingress {
    description    = "ICMP health checks from Yandex Cloud subnets"
    protocol       = "ICMP"
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  ingress {
    description    = "Pod and service traffic"
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = [var.cluster_ipv4_range, var.service_ipv4_range]
  }

  egress {
    description       = "Outgoing service traffic between master and nodes"
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Node access to external resources"
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "public_services" {
  folder_id   = var.folder_id
  network_id  = var.network_id
  name        = "${var.name_prefix}-public-services"
  description = "Rules for exposing services from the internet"

  ingress {
    description    = "HTTP"
    port           = 80
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "NodePort"
    from_port      = 30000
    to_port        = 32767
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "kubernetes_api" {
  folder_id   = var.folder_id
  network_id  = var.network_id
  name        = "${var.name_prefix}-kubernetes-api"
  description = "Rules for access to the Kubernetes API"

  ingress {
    description    = "Kubernetes API HTTPS"
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = var.kubernetes_api_allowed_cidrs
  }

  ingress {
    description    = "Kubernetes API"
    port           = 6443
    protocol       = "TCP"
    v4_cidr_blocks = var.kubernetes_api_allowed_cidrs
  }
}

resource "yandex_vpc_security_group" "ssh" {
  folder_id   = var.folder_id
  network_id  = var.network_id
  name        = "${var.name_prefix}-ssh"
  description = "Rules for SSH access to Kubernetes worker nodes"

  ingress {
    description    = "SSH"
    port           = 22
    protocol       = "TCP"
    v4_cidr_blocks = var.ssh_allowed_cidrs
  }
}
