resource "cloudflare_zero_trust_gateway_policy" "dns_filtering" {
  account_id  = local.account_id
  name        = "SASE-DNS-Security"
  description = "Block malware, phishing, and adult content"
  precedence  = 1
  action      = "block"
  filters     = ["dns"]

  rule_settings {
    block_page_enabled = true
    block_page_reason  = "SASE Policy: This domain is blocked for security reasons."
  }

  traffic = "dns.fqdn matches \".*.(xyz|top|gq|ml|cf|ga|tk|download|bid|date)\""
}

resource "cloudflare_zero_trust_gateway_policy" "http_filtering" {
  account_id  = local.account_id
  name        = "SASE-HTTP-Security"
  description = "Block high-risk categories and enforce TLS"
  precedence  = 2
  action      = "block"
  filters     = ["http"]

  rule_settings {
    block_page_enabled = true
    block_page_reason  = "SASE Policy: Content blocked by security policy."
  }

  traffic = "http.request.uri contains \"torrent\" OR http.request.uri contains \"proxy\""
}

resource "cloudflare_zero_trust_gateway_policy" "split_tunnel" {
  account_id  = local.account_id
  name        = "SASE-Split-Tunnel-Corp"
  description = "Route corporate traffic through Gateway, bypass for non-corporate"
  precedence  = 3
  action      = "allow"
  filters     = ["dns", "http"]

  traffic = "dst.ip in { 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 }"
}

resource "cloudflare_zero_trust_gateway_proxy_endpoint" "sase_proxy" {
  account_id = local.account_id
  name       = "SASE-Gateway-Proxy"
  ips        = ["203.0.113.10", "198.51.100.10"]
}
