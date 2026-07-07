variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zero Trust permissions"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare zone ID for the domain"
  type        = string
}

variable "domain" {
  description = "Domain used for SASE applications (e.g., sase.example.com)"
  type        = string
}

variable "sites" {
  description = "Multi-site definitions for the SASE deployment"
  type = map(object({
    cidr     = string
    peer_ips = list(string)
    location = string
  }))
  default = {
    "site-a" = {
      cidr     = "10.0.1.0/24"
      peer_ips = ["10.0.1.1", "10.0.1.2"]
      location = "Amman, Jordan"
    }
    "site-b" = {
      cidr     = "10.0.2.0/24"
      peer_ips = ["10.0.2.1", "10.0.2.2"]
      location = "Dubai, UAE"
    }
    "hub" = {
      cidr     = "10.0.0.0/24"
      peer_ips = ["10.0.0.1"]
      location = "AWS eu-central-1"
    }
  }
}

variable "allowed_email_domains" {
  description = "Email domains allowed for SASE access"
  type        = list(string)
  default     = ["example.com"]
}

variable "posture_checks" {
  description = "Enable/disable device posture checks"
  type        = bool
  default     = true
}
