variable "domain" {
  description = "DNS zone / mail domain for bot email addresses"
  type        = string
}

variable "create_renovate_hook" {
  description = "Create gitlab_project_hook for Renovate CE when docker_compose + renovate are enabled"
  type        = bool
  default     = false
}

variable "renovate_dns_label" {
  description = "DNS label for Renovate webhook host"
  type        = string
  default     = "renovate"
}

variable "renovate_webhook_token" {
  description = "Webhook secret (must match MEND_RNV_WEBHOOK_SECRET on Renovate)"
  type        = string
  sensitive   = true
  default     = ""
}
