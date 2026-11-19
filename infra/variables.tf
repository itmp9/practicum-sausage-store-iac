variable "cloud_id" {
  description = "ID учебного облака"
  type        = string
}

variable "folder_id" {
  description = "ID выделенного учебного каталога"
  type        = string
}

variable "zone" {
  description = "Зона размещения ВМ и подсети"
  type        = string
}

variable "subnet_cidr" {
  description = "Адресное пространство подсети проекта"
  type        = string
}

variable "yc_service_account_key_file" {
  description = "Путь к авторизованному ключу сервисного аккаунта"
  type        = string
  nullable    = false
}

variable "ssh_public_key" {
  description = "Публичный ключ пользователя ubuntu на учебных ВМ"
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) [A-Za-z0-9+/=]+", trimspace(var.ssh_public_key)))
    error_message = "Укажите публичный SSH-ключ OpenSSH."
  }
}

variable "ssh_source_cidrs" {
  description = "Разрешённые адреса GitLab Runner и оператора для SSH"
  type        = list(string)

  validation {
    condition = length(var.ssh_source_cidrs) > 0 && alltrue([
      for cidr in var.ssh_source_cidrs : can(cidrnetmask(cidr)) && !endswith(cidr, "/0")
    ])
    error_message = "Укажите ограниченные IPv4 CIDR для SSH."
  }
}

variable "vault_source_cidrs" {
  description = "Разрешённые адреса выхода учебного кластера, CI и ревьюера для Vault"
  type        = list(string)

  validation {
    condition = length(var.vault_source_cidrs) > 0 && alltrue([
      for cidr in var.vault_source_cidrs : can(cidrnetmask(cidr)) && !endswith(cidr, "/0")
    ])
    error_message = "Укажите ограниченные IPv4 CIDR для Vault."
  }
}
