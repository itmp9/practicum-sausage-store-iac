resource "yandex_vpc_network" "infra" {
  name = "sausage-store"
}

resource "yandex_vpc_subnet" "infra" {
  name           = "sausage-store"
  zone           = var.zone
  network_id     = yandex_vpc_network.infra.id
  v4_cidr_blocks = [var.subnet_cidr]
}

locals {
  vm_ingress = {
    ssh   = { port = 22, cidrs = var.ssh_source_cidrs }
    vault = { port = 8200, cidrs = var.vault_source_cidrs }
  }
}

resource "yandex_vpc_security_group" "infra_sg" {
  for_each = toset(["dev", "prod"])

  name       = "sausage-store-${each.key}"
  network_id = yandex_vpc_network.infra.id

  dynamic "ingress" {
    for_each = local.vm_ingress

    content {
      description    = ingress.key
      protocol       = "TCP"
      port           = ingress.value.port
      v4_cidr_blocks = ingress.value.cidrs
    }
  }

  egress {
    description    = "All outbound traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

output "prod_security_group_id" {
  value = yandex_vpc_security_group.infra_sg["prod"].id
}

output "prod_security_group_name" {
  value = yandex_vpc_security_group.infra_sg["prod"].name
}
