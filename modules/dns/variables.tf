variable "domain_name" {
  type        = string
  description = "Domain name for the DNS zone"
}

variable "server_ipv4" {
  type        = string
  description = "IPv4 address for the web1 A record"
}

variable "dmarc_value" {
  type        = string
  default     = "v=DMARC1;p=quarantine;pct=100;rua=mailto:info@example.com"
  description = "DMARC TXT record value"
}

variable "dkim_value" {
  type        = string
  default     = ""
  description = "DKIM TXT record value (will be automatically chunked if >255 characters)"
}

variable "spf_value" {
  type        = string
  default     = "v=spf1 mx -all"
  description = "SPF TXT record value"
}

variable "mail_mx_value" {
  type        = string
  default     = "10 mail.example.com"
  description = "MX record value (priority and hostname)"
}

variable "mail_ipv4" {
  type        = string
  default     = ""
  description = "Mail server IPv4 address for A record"
}

variable "mail_ipv6" {
  type        = string
  default     = ""
  description = "Mail server IPv6 address for AAAA record"
}

variable "mail_cname_target" {
  type        = string
  default     = "mail.example.com"
  description = "CNAME target for autoconfig and autodiscover records"
}

variable "tlsa_value" {
  type        = string
  default     = ""
  description = "TLSA record value"
}

variable "tlsa_name" {
  type        = string
  default     = "_25._tcp.mail.example.com"
  description = "TLSA record name"
}

variable "srv_value" {
  type        = string
  default     = "0 0 443 mail.example.com."
  description = "SRV record value: priority weight port target (target must end with a dot)"
}

variable "srv_name" {
  type        = string
  default     = "_autodiscover._tcp"
  description = "SRV record name"
}

variable "iodef_value" {
  type        = string
  default     = "mailto:info@example.com"
  description = "CAA IODEF record value"
}

variable "contact_value" {
  type        = string
  default     = "mailto:info@example.com"
  description = "CAA contact record value"
}

variable "enable_caa_records" {
  type        = bool
  default     = true
  description = "Whether to create CAA records (issue, issuewild, iodef, contact)"
}
