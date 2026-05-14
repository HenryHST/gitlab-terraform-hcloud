variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Public SSH key for server access"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)\\s+", var.ssh_public_key))
    error_message = "SSH public key must start with ssh-rsa, ssh-ed25519, or ecdsa-sha2-nistp***."
  }
}

variable "ssh_private_key_path" {
  description = "Path to private SSH key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "server_name" {
  description = "Name of the server"
  type        = string
  default     = "web1"

  validation {
    condition     = length(var.server_name) > 0 && length(var.server_name) <= 63
    error_message = "Server name must be 1–63 characters."
  }
}

variable "server_type" {
  description = "Server type (e.g. cx22 = 2 vCPU 4GB, cpx22 = 3 vCPU 4GB)"
  type        = string
  default     = "cx23"

  validation {
    condition     = can(regex("^(cx|cpx|ccx)[0-9]{2,3}$", var.server_type))
    error_message = "Server type must be a valid Hetzner type (e.g. cx11, cx22, cpx21, ccx23)."
  }
}

variable "location" {
  description = "Server location (fsn1 = Falkenstein, nbg1 = Nuremberg, hel1 = Helsinki)"
  type        = string
  default     = "fsn1"

  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], var.location)
    error_message = "Location must be one of: fsn1, nbg1, hel1, ash, hil."
  }
}

variable "github_repo" {
  description = "GitHub repository URL to clone"
  type        = string
  default     = "https://github.com/HenryHST/astro-deploy.git"

  validation {
    condition     = can(regex("^https://", var.github_repo))
    error_message = "GitHub repo must be an HTTPS URL."
  }
}

variable "hetzner_api_key" {
  description = "Hetzner DNS API Key for Traefik Let's Encrypt"
  type        = string
  sensitive   = true
}

variable "traefik_dashboard_credentials" {
  description = "BasicAuth credentials for Traefik dashboard (format: user:$$apr1$$hash$$)"
  type        = string
  sensitive   = true

  validation {
    condition     = strcontains(var.traefik_dashboard_credentials, ":")
    error_message = "Traefik credentials must be in format user:password_or_hash."
  }
}

variable "site_url" {
  description = "Main URL of the website"
  type        = string
  default     = "https://cicd-showcase.de"

  validation {
    condition     = can(regex("^https://", var.site_url))
    error_message = "Site URL must start with https://."
  }
}



variable "domain_cicd_showcase_de" {
  description = "Domain for the website (e.g. cicd-showcase.de)"
  type        = string
  default     = "cicd-showcase.de"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.domain_cicd_showcase_de)) && strcontains(var.domain_cicd_showcase_de, ".")
    error_message = "Domain must be a valid hostname with at least one dot (e.g. example.com)."
  }
}

variable "mail_mx_value" {
  description = "MX record value: priority and hostname (e.g. 10 mail.example.com)"
  type        = string
  default     = "10 mail.henrystadthagen.de"

  validation {
    condition     = can(regex("^[0-9]+\\s+[a-z0-9]([a-z0-9.-]*[a-z0-9])?(\\.?)$", var.mail_mx_value))
    error_message = "MX value must be 'priority hostname' (e.g. 10 mail.example.com)."
  }
}
variable "dmarc_value" {
  description = "DMARC TXT record value (must contain v=DMARC1)"
  type        = string
  default     = "v=DMARC1;p=quarantine;pct=100;rua=mailto:info@henrystadthagen.de"

  validation {
    condition     = strcontains(var.dmarc_value, "v=DMARC1")
    error_message = "DMARC value must contain v=DMARC1."
  }
}
variable "dkim_value" {
  description = "DKIM TXT record value for the domain"
  type        = string
  default     = "v=DKIM1;k=rsa;t=s;s=email;p=MMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2nXMiln1XG9H6pS7bspMDR9PLnm9FjzMwpy1U7ocBZhh/vQmTAZerL2Az3FLKmy4INqAQkz7E9TtkZQaScB6acwOPdPu34oHU9iYgXSvIOXbKmjapUboBvejEjN9wAPWMiy7oTEkUHmY7ZhrAkdKN2H77Tvj4L5ay3v6afyBWyX1hGx/aU/qvwSRVOkQ8LVOaaJsvGxsji1sYvhYKb6ksLkEhccnfXItisNmUBJt2Fkjd0aGj4IFx+Hbl+Ws0ENdbVZuQzxK4RMfgiwjHfi4gmvHICsWbvV7oWbG2HZXRj+6WiTplei1y63Ls3IkSZwVI524EKCXzg8+vcn/yBW1LwIDAQAB"
}
variable "spf_value" {
  description = "SPF TXT record value for the domain"
  type        = string
  default     = "v=spf1 ip4:91.107.238.126 mx -all"

  validation {
    condition     = strcontains(var.spf_value, "v=spf1")
    error_message = "SPF value must contain v=spf1."
  }
}
variable "tlsa_value" {
  description = "TLSA record value (usage selector matching cert)"
  type        = string
  default     = "3 1 1 aed2a71af8346edd13e4c0e36a9662a329cbb59cf1283573ea75d69ef9600b4f"
}
variable "srv_value" {
  description = "SRV value: priority weight port target (target must end with a dot)"
  type        = string
  default     = "0 0 443 mail.henrystadthagen.de."

  validation {
    condition     = can(regex("^[0-9]+\\s+[0-9]+\\s+[0-9]+\\s+.+\\.$", var.srv_value))
    error_message = "SRV value must be 'priority weight port target.' (target must end with a dot)."
  }
}
variable "iodef_value" {
  description = "CAA IODEF record value (e.g. mailto:)"
  type        = string
  default     = "mailto:info@henrystadthagen.de"
}

variable "contact_value" {
  description = "CAA contact record value (e.g. mailto:)"
  type        = string
  default     = "mailto:info@henrystadthagen.de"
}