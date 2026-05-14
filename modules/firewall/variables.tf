variable "firewall_name" {
  type        = string
  description = "Name of the firewall"
}

variable "enable_ssh" {
  type        = bool
  default     = true
  description = "Enable SSH access on port 22"
}

variable "ssh_source_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  description = "Source IPs allowed for SSH access"
}

variable "enable_http" {
  type        = bool
  default     = true
  description = "Enable HTTP access on port 80"
}

variable "http_source_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  description = "Source IPs allowed for HTTP access"
}

variable "enable_https" {
  type        = bool
  default     = true
  description = "Enable HTTPS access on port 443"
}

variable "https_source_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  description = "Source IPs allowed for HTTPS access"
}

variable "enable_dns" {
  type        = bool
  default     = true
  description = "Enable DNS access on port 53 (TCP and UDP)"
}

variable "dns_source_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  description = "Source IPs allowed for DNS access"
}

variable "enable_icmp" {
  type        = bool
  default     = true
  description = "Enable ICMP (ping) access"
}

variable "icmp_source_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  description = "Source IPs allowed for ICMP access"
}

variable "enable_node_exporter" {
  type        = bool
  default     = true
  description = "Enable Node Exporter metrics access"
}

variable "node_exporter_source_ips" {
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
  description = "Source IPs allowed for Node Exporter access"
}

variable "node_exporter_port" {
  type        = number
  default     = 9100
  description = "Port for Node Exporter metrics"
}

variable "custom_rules" {
  type = list(object({
    direction       = string
    protocol        = string
    port            = optional(string)
    source_ips      = optional(list(string), [])
    destination_ips = optional(list(string), [])
  }))
  default     = []
  description = "Additional custom firewall rules"
}
