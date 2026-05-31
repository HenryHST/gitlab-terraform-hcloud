variable "node" {
  type        = string
  description = "Proxmox node name for the GitLab VM"

  validation {
    condition     = length(trimspace(var.node)) > 0 && can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.node))
    error_message = "node must be a non-empty Proxmox node name (letters, digits, ., _, -)."
  }
}

variable "runner_node" {
  type        = string
  default     = ""
  description = "Proxmox node for GitLab Runner VM; empty uses node"

  validation {
    condition     = var.runner_node == "" || can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.runner_node))
    error_message = "runner_node must be empty or a valid Proxmox node name."
  }
}

variable "api_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://pve.example:8006/api2/json"

  validation {
    condition     = can(regex("^https://.+/api2/json$", var.api_url))
    error_message = "api_url must be https://HOST:PORT/api2/json (no trailing slash)."
  }
}

variable "api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"

  validation {
    condition     = length(var.api_token) >= 8 && !can(regex("\\s", var.api_token))
    error_message = "api_token must be at least 8 characters and must not contain whitespace."
  }
}

variable "api_token_id" {
  type        = string
  description = "Proxmox API token ID, e.g. terraform@pam!terraform"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+@[A-Za-z0-9]+![A-Za-z0-9._-]+$", var.api_token_id))
    error_message = "api_token_id must match USER@REALM!TOKENNAME (e.g. terraform@pam!terraform)."
  }
}

variable "tls_insecure" {
  type        = bool
  default     = false
  description = "Skip TLS verification for snippet upload curl"
}

variable "gitlab_docker_enabled" {
  type        = bool
  default     = true
  description = "Upload cloud-init snippet and set cicustom on GitLab VM"
}

variable "gitlab_docker_user_data" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Rendered cloud-init YAML (#cloud-config) for GitLab docker_compose stack"
}

variable "vm_state" {
  type        = string
  default     = "stopped"
  description = "VM state"

  validation {
    condition     = contains(["stopped", "running"], var.vm_state)
    error_message = "vm_state must be one of: stopped, running."
  }
}

variable "vm_state_runner" {
  type        = string
  default     = "stopped"
  description = "VM state for runner"

  validation {
    condition     = contains(["stopped", "running"], var.vm_state_runner)
    error_message = "vm_state_runner must be one of: stopped, running."
  }
}

variable "cloud_init_snippet_name" {
  type        = string
  default     = "gitlab-docker-cloud-init.yaml"
  description = "Filename under snippets/ on Proxmox storage"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+\\.ya?ml$", var.cloud_init_snippet_name))
    error_message = "cloud_init_snippet_name must be a .yaml or .yml filename (no path separators)."
  }
}

variable "snippet_storage" {
  type        = string
  default     = "local"
  description = "Proxmox storage ID for snippet upload (must allow content snippets)"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.snippet_storage))
    error_message = "snippet_storage must be a valid Proxmox storage ID."
  }
}

variable "enable_clone" {
  type        = bool
  default     = true
  description = "Clone from template instead of blank disk"
}

variable "clone_template" {
  type        = string
  default     = "ubuntu-2404-cloudinit"
  description = "Template VM name when enable_clone is true"

  validation {
    condition     = !var.enable_clone || length(trimspace(var.clone_template)) > 0
    error_message = "clone_template must be non-empty when enable_clone is true."
  }
}

variable "clone_full" {
  type        = bool
  default     = true
  description = "Full clone vs linked clone"
}

variable "enable_runner" {
  type        = bool
  default     = true
  description = "Create a second VM for GitLab Runner"
}

variable "gitlab_vm_name" {
  type        = string
  default     = "gitlab"
  description = "Proxmox VM name for GitLab"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.gitlab_vm_name))
    error_message = "gitlab_vm_name must be a valid Proxmox VM name."
  }
}

variable "runner_vm_name" {
  type        = string
  default     = "gitlab-runner"
  description = "Proxmox VM name for GitLab Runner"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.runner_vm_name))
    error_message = "runner_vm_name must be a valid Proxmox VM name."
  }
}

variable "gitlab_ipconfig0" {
  type        = string
  description = "Proxmox ipconfig0 for GitLab, e.g. ip=10.20.0.10/16,gw=10.20.0.1"

  validation {
    condition     = can(regex("^ip=", var.gitlab_ipconfig0))
    error_message = "gitlab_ipconfig0 must start with \"ip=\" (Proxmox cloud-init ipconfig0 format)."
  }
}

variable "runner_ipconfig0" {
  type        = string
  description = "Proxmox ipconfig0 for Runner VM"

  validation {
    condition     = can(regex("^ip=", var.runner_ipconfig0))
    error_message = "runner_ipconfig0 must start with \"ip=\" (Proxmox cloud-init ipconfig0 format)."
  }
}

variable "ssh_public_key" {
  type        = string
  sensitive   = true
  description = "SSH public key for cloud-init (ciuser)"

  validation {
    condition = (
      length(trimspace(var.ssh_public_key)) > 0 &&
      can(regex("^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp256)", trimspace(var.ssh_public_key)))
    )
    error_message = "ssh_public_key must be a non-empty OpenSSH public key (ssh-rsa, ssh-ed25519, ecdsa-sha2-nistp256, or ssh-dss)."
  }
}

variable "ciuser" {
  type        = string
  description = "Cloud-init default user"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*[$]?$", var.ciuser)) && length(var.ciuser) <= 32
    error_message = "ciuser must be a valid Linux username (lowercase, max 32 characters)."
  }
}

variable "cipassword" {
  type        = string
  sensitive   = true
  description = "Cloud-init password for ciuser (min. 8 characters)"

  validation {
    condition     = length(var.cipassword) >= 8
    error_message = "cipassword must be at least 8 characters."
  }
}

variable "nameserver" {
  type        = string
  description = "DNS nameserver for cloud-init"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.nameserver)) || can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*\\.[a-zA-Z]{2,}$", var.nameserver))
    error_message = "nameserver must be an IPv4 address or a hostname."
  }
}

variable "searchdomain" {
  type        = string
  description = "DNS search domain for cloud-init"

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]*\\.[a-zA-Z]{2,}$", var.searchdomain))
    error_message = "searchdomain must be a valid domain name (e.g. example.com)."
  }
}

variable "vm_qemu_os" {
  type        = string
  default     = "l26"
  description = "QEMU OS type (l26 for Linux 2.6+)"

  validation {
    condition     = contains(["l26", "other", "l24"], var.vm_qemu_os)
    error_message = "vm_qemu_os must be one of: l26, other, l24."
  }
}

variable "vm_bios" {
  type        = string
  default     = "ovmf"
  description = "VM firmware: ovmf (UEFI) or seabios"

  validation {
    condition     = contains(["ovmf", "seabios"], var.vm_bios)
    error_message = "vm_bios must be ovmf or seabios."
  }
}

variable "gitlab_cores" {
  type        = number
  default     = 4
  description = "GitLab VM CPU cores"

  validation {
    condition     = var.gitlab_cores >= 1 && var.gitlab_cores <= 512 && floor(var.gitlab_cores) == var.gitlab_cores
    error_message = "gitlab_cores must be an integer between 1 and 512."
  }
}

variable "gitlab_sockets" {
  type        = number
  default     = 1
  description = "GitLab VM CPU sockets"

  validation {
    condition     = var.gitlab_sockets >= 1 && var.gitlab_sockets <= 16 && floor(var.gitlab_sockets) == var.gitlab_sockets
    error_message = "gitlab_sockets must be an integer between 1 and 16."
  }
}

variable "gitlab_memory" {
  type        = number
  default     = 8192
  description = "GitLab VM memory in MiB"

  validation {
    condition     = var.gitlab_memory >= 512 && var.gitlab_memory <= 2097152 && floor(var.gitlab_memory) == var.gitlab_memory
    error_message = "gitlab_memory must be an integer between 512 and 2097152 MiB."
  }
}

variable "runner_cores" {
  type        = number
  default     = 2
  description = "Runner VM CPU cores"

  validation {
    condition     = var.runner_cores >= 1 && var.runner_cores <= 512 && floor(var.runner_cores) == var.runner_cores
    error_message = "runner_cores must be an integer between 1 and 512."
  }
}

variable "runner_sockets" {
  type        = number
  default     = 1
  description = "Runner VM CPU sockets"

  validation {
    condition     = var.runner_sockets >= 1 && var.runner_sockets <= 16 && floor(var.runner_sockets) == var.runner_sockets
    error_message = "runner_sockets must be an integer between 1 and 16."
  }
}

variable "runner_memory" {
  type        = number
  default     = 4096
  description = "Runner VM memory in MiB"

  validation {
    condition     = var.runner_memory >= 512 && var.runner_memory <= 2097152 && floor(var.runner_memory) == var.runner_memory
    error_message = "runner_memory must be an integer between 512 and 2097152 MiB."
  }
}

variable "disk_storage" {
  type        = string
  default     = "local-lvm"
  description = "Storage for VM disks"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.disk_storage))
    error_message = "disk_storage must be a valid Proxmox storage ID."
  }
}

variable "disk_size" {
  type        = string
  default     = "32G"
  description = "Disk size when not cloning (Proxmox format, e.g. 32G)"

  validation {
    condition     = can(regex("^[0-9]+[GM]$", var.disk_size))
    error_message = "disk_size must use Proxmox size format, e.g. 32G or 512M."
  }
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Linux bridge for VM NIC"

  validation {
    condition     = can(regex("^vmbr[0-9]+$", var.network_bridge))
    error_message = "network_bridge must match vmbrN (e.g. vmbr0)."
  }
}

variable "network_model" {
  type        = string
  default     = "virtio"
  description = "NIC model (virtio recommended)"

  validation {
    condition     = contains(["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3"], var.network_model)
    error_message = "network_model must be one of: virtio, e1000, e1000e, rtl8139, vmxnet3."
  }
}

variable "network_link_down" {
  type        = bool
  default     = false
  description = "Start NIC link down"
}

variable "network_firewall" {
  type        = bool
  default     = false
  description = "Enable Proxmox firewall on NIC"
}

variable "scsihw" {
  type        = string
  default     = "virtio-scsi-pci"
  description = "SCSI controller type"

  validation {
    condition     = contains(["virtio-scsi-pci", "virtio-scsi-single", "lsi", "lsi53c810", "megasas", "pvscsi"], var.scsihw)
    error_message = "scsihw must be a supported Proxmox SCSI controller (e.g. virtio-scsi-pci)."
  }
}

variable "bootdisk" {
  type        = string
  default     = "scsi0"
  description = "Boot disk device"

  validation {
    condition     = can(regex("^(scsi|ide|sata|virtio)[0-9]+$", var.bootdisk))
    error_message = "bootdisk must be a Proxmox disk ID (e.g. scsi0, ide2)."
  }
}

variable "onboot" {
  type        = bool
  default     = true
  description = "Start VM on Proxmox host boot"
}

variable "qemu_agent" {
  type        = number
  default     = 1
  description = "QEMU guest agent (0 or 1)"

  validation {
    condition     = contains([0, 1], var.qemu_agent)
    error_message = "qemu_agent must be 0 (disabled) or 1 (enabled)."
  }
}

variable "clone_wait" {
  type        = number
  default     = 10
  description = "Seconds to wait after clone"

  validation {
    condition     = var.clone_wait >= 0 && var.clone_wait <= 600 && floor(var.clone_wait) == var.clone_wait
    error_message = "clone_wait must be an integer between 0 and 600 seconds."
  }
}

variable "additional_wait" {
  type        = number
  default     = 5
  description = "Extra wait after clone before configure"

  validation {
    condition     = var.additional_wait >= 0 && var.additional_wait <= 600 && floor(var.additional_wait) == var.additional_wait
    error_message = "additional_wait must be an integer between 0 and 600 seconds."
  }
}

variable "skip_ipv6" {
  type        = bool
  default     = true
  description = "Skip IPv6 in provider"
}

variable "tags" {
  type        = string
  default     = "docker,gitlab"
  description = "Proxmox VM tags (comma-separated)"

  validation {
    condition     = length(trimspace(var.tags)) > 0 && !can(regex("^,|,,|,$", var.tags))
    error_message = "tags must be a non-empty comma-separated list without empty entries."
  }
}
