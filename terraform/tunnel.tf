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

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "sase_tunnel_configs" {
  for_each   = var.sites
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels[each.key].id

  config {
    dynamic "ingress_rule" {
      for_each = each.key == "hub" ? [
        { hostname = "admin.${var.domain}", service = "https://localhost:8443" },
        { hostname = "monitor.${var.domain}", service = "https://localhost:9090" },
        ] : [
        { hostname = "*.${var.domain}", service = "http://localhost:80" },
      ]
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
      }
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "sase_dns" {
  for_each = cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels
  zone_id  = var.zone_id
  name     = each.key == "hub" ? "*" : each.key
  type     = "CNAME"
  value    = "${each.value.id}.cfargotunnel.com"
  proxied  = true
}

output "tunnel_ids" {
  value = {
    for k, t in cloudflare_zero_trust_tunnel_cloudflared.sase_site_tunnels : k => t.id
  }
}

output "access_applications" {
  value = {
    for k, a in cloudflare_zero_trust_access_application.sase_apps : k => a.domain
  }
}
