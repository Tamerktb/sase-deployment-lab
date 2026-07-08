resource "cloudflare_zero_trust_tunnel_cloudflared" "sase_site_tunnels" {
  for_each   = var.sites
  account_id = local.account_id
  name       = "sase-${each.key}"
  secret     = base64encode(random_id.tunnel_secret[each.key].hex)
}

resource "random_id" "tunnel_secret" {
  for_each    = var.sites
  byte_length = 32
}

# Ingress rules per site, derived from var.site_apps.
#
# IMPORTANT — backend addressing depends on where cloudflared runs:
#   * Docker sidecar (this lab): cloudflared is its OWN container, so
#     "localhost" points at the cloudflared container itself, NOT the app.
#     Backends must use Docker service names (http://site-a-web:80).
#   * Real host/VM: cloudflared runs next to the service, so
#     http://localhost:<port> is correct there.
# var.site_apps defaults use Docker service names to match docker-compose.yml.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "sase_tunnel_configs" {
  for_each   = var.sites
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels[each.key].id

  config {
    dynamic "ingress_rule" {
      for_each = { for name, app in var.site_apps : name => app if app.site == each.key }
      content {
        hostname = "${ingress_rule.key}.${var.domain}"
        service  = ingress_rule.value.service
      }
    }
    # Catch-all: anything not explicitly routed gets a 404
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# One DNS record per app hostname, pointing at the tunnel of the site
# that actually hosts it. This is what makes wiki.<domain> reach Site-A's
# tunnel and jenkins.<domain> reach Site-B's tunnel — a single wildcard
# record pointing at the hub would send ALL app traffic to the hub tunnel,
# where those hostnames have no ingress rule (404).
resource "cloudflare_record" "sase_app_dns" {
  for_each = var.site_apps
  zone_id  = var.zone_id
  name     = each.key
  type     = "CNAME"
  value    = "${cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels[each.value.site].id}.cfargotunnel.com"
  proxied  = true
}

# Per-site records (site-a.<domain>, site-b.<domain>, hub.<domain>)
# for direct access to each site's default web service.
resource "cloudflare_record" "sase_site_dns" {
  for_each = cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels
  zone_id  = var.zone_id
  name     = each.key
  type     = "CNAME"
  value    = "${each.value.id}.cfargotunnel.com"
  proxied  = true
}

output "tunnel_ids" {
  value = {
    for k, t in cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels : k => t.id
  }
}

output "app_hostnames" {
  value = {
    for name, app in var.site_apps : "${name}.${var.domain}" => app.site
  }
}

output "access_applications" {
  value = {
    for k, a in cloudflare_zero_trust_access_application.sase_apps : k => a.domain
  }
}
