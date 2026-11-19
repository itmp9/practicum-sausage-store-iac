resource "yandex_compute_instance" "vm_dev" {
  name                      = "vm-dev"
  platform_id               = "standard-v3"
  allow_stopping_for_update = true
  labels = {
    project     = "sausage-store"
    environment = "dev"
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
    security_group_ids = [yandex_vpc_security_group.infra_sg["dev"].id]
  }

  metadata = {
    ssh-keys           = "ubuntu:${trimspace(var.ssh_public_key)}"
    serial-port-enable = "0"
  }
}

output "vm_dev_id" {
  value = yandex_compute_instance.vm_dev.id
}

output "vm_dev_name" {
  value = yandex_compute_instance.vm_dev.name
}

output "vm_dev_address" {
  value = yandex_compute_instance.vm_dev.network_interface[0].nat_ip_address
}
