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

variable "posture_integration_name" {
  description = "Name of the Cloudflare Device Posture integration (created manually in dashboard)"
  type        = string
  default     = "SASE-Device-Posture"
}

variable "gateway_proxy_ips" {
  description = "Routable IPs for the Gateway proxy endpoint (leave empty to skip). Must be real IPs your org owns."
  type        = list(string)
  default     = []
}

variable "site_apps" {
  description = <<-DESC
    App hostname -> owning site + backend service.
    Backends use Docker service names because cloudflared runs as a sidecar
    container in this lab (localhost inside the sidecar is NOT the app).
    On a real host where cloudflared runs beside the service, replace with
    http://localhost:<port>.
  DESC
  type = map(object({
    site    = string
    service = string
  }))
  default = {
    "wiki"    = { site = "site-a", service = "http://site-a-web:80" }
    "jenkins" = { site = "site-b", service = "http://site-b-web:80" }
    "admin"   = { site = "hub",    service = "http://grafana:3000" }
    "monitor" = { site = "hub",    service = "http://hub-monitor:80" }
  }
}
