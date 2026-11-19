resource "yandex_compute_instance" "vm_prod" {
  name                      = "vm-prod"
  platform_id               = "standard-v3"
  allow_stopping_for_update = true
  labels = {
    project     = "sausage-store"
    environment = "prod"
  }

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 1
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-hdd"
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.infra.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.infra_sg["prod"].id]
  }

  metadata = {
    ssh-keys           = "ubuntu:${trimspace(var.ssh_public_key)}"
    serial-port-enable = "0"
  }
}

output "vm_prod_id" {
  value = yandex_compute_instance.vm_prod.id
}

output "vm_prod_name" {
  value = yandex_compute_instance.vm_prod.name
}

output "vm_prod_address" {
  value = yandex_compute_instance.vm_prod.network_interface[0].nat_ip_address
}
