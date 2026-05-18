variable "node" {
  type        = string
  description = "Proxmox cluster node name (target_node for the GitLab VM)"
}

variable "runner_node" {
  type        = string
  default     = ""
  description = "Node for the runner VM; empty = node"
}

variable "api_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://pve.example.com:8006/api2/json"
}

variable "api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "api_token_id" {
  type        = string
  description = "Proxmox API token ID (USER@REALM!TOKENNAME)"
}

variable "tls_insecure" {
  type        = bool
  default     = true
  description = "Skip TLS verification for snippet upload (curl -k)"
}

variable "gitlab_docker_enabled" {
  type        = bool
  default     = true
  description = "Upload gitlab-docker cloud-init snippet and set cicustom on the GitLab VM"
}

variable "gitlab_docker_user_data" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Rendered cloud-init user data for GitLab docker_compose stack"
}

variable "cloud_init_snippet_name" {
  type        = string
  default     = "gitlab-docker-cloud-init.yaml"
  description = "Filename under snippets/ on Proxmox storage"
}

variable "snippet_storage" {
  type        = string
  default     = "local"
  description = "Proxmox storage ID for snippet upload"
}

variable "enable_clone" {
  type        = bool
  default     = false
  description = "Clone from clone_template instead of creating an empty disk"
}

variable "enable_runner" {
  type        = bool
  default     = false
  description = "Create a second VM for GitLab Runner"
}

variable "gitlab_ipconfig0" {
  type        = string
  description = "Cloud-Init ipconfig0 for the GitLab VM"
}

variable "runner_ipconfig0" {
  type        = string
  description = "Cloud-Init ipconfig0 for the runner VM"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Cloud-Init sshkeys"
}

variable "ciuser" {
  type        = string
  description = "Cloud-Init login user"
}

variable "cipassword" {
  type        = string
  sensitive   = true
  description = "Cloud-Init login password"
}

variable "nameserver" {
  type        = string
  description = "Cloud-Init nameserver"
}

variable "searchdomain" {
  type        = string
  description = "Cloud-Init DNS search domain"
}

variable "clone_template" {
  type        = string
  default     = "ubuntu-tmp"
  description = "Template to clone when enable_clone is true"
}

variable "clone_full" {
  type        = bool
  default     = true
  description = "Full clone when cloning"
}

variable "vm_qemu_os" {
  type        = string
  default     = "l26"
  description = "QEMU OS type (proxmox_vm_qemu.qemu_os)"
}

variable "vm_bios" {
  type        = string
  default     = "ovmf"
  description = "VM BIOS type"
}

variable "gitlab_cores" {
  type        = number
  default     = 4
  description = "CPU cores for the GitLab VM"
}

variable "gitlab_sockets" {
  type        = number
  default     = 1
  description = "CPU sockets for the GitLab VM"
}

variable "gitlab_memory" {
  type        = number
  default     = 12288
  description = "Memory (MiB) for the GitLab VM"
}

variable "runner_cores" {
  type        = number
  default     = 2
  description = "CPU cores for the runner VM"
}

variable "runner_sockets" {
  type        = number
  default     = 1
  description = "CPU sockets for the runner VM"
}

variable "runner_memory" {
  type        = number
  default     = 2048
  description = "Memory (MiB) for the runner VM"
}

variable "disk_storage" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for VM disks when not cloning"
}

variable "disk_size" {
  type        = string
  default     = "20G"
  description = "Disk size when not cloning"
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Network bridge for VM NICs"
}

variable "scsihw" {
  type        = string
  default     = "virtio-scsi-pci"
  description = "SCSI controller type"
}

variable "bootdisk" {
  type        = string
  default     = "scsi0"
  description = "Boot disk device"
}

variable "gitlab_vm_name" {
  type        = string
  default     = "gitlab"
  description = "Proxmox VM name for GitLab"
}

variable "runner_vm_name" {
  type        = string
  default     = "gitlab-runner"
  description = "Proxmox VM name for GitLab Runner"
}
