# Block domains flagged by Cloudflare's threat intelligence (Malware = 80, Phishing = 83).
# This is the production-grade approach: category IDs come from Cloudflare's
# continuously updated threat feeds, not static pattern matching.
# Full ID list: Zero Trust > Gateway > Firewall policies > DNS > Security Categories
resource "cloudflare_zero_trust_gateway_policy" "dns_security_categories" {
  account_id  = local.account_id
  name        = "SASE-DNS-Threat-Intel"
  description = "Block malware and phishing domains via Cloudflare threat intelligence"
  precedence  = 1
  action      = "block"
  filters     = ["dns"]

  rule_settings {
    block_page_enabled = true
    block_page_reason  = "SASE Policy: This domain is flagged as malicious."
  }

  traffic = "any(dns.security_category[*] in {80 83})"
}

# Defense-in-depth: additionally block a short list of TLDs with high abuse rates.
# NOTE: the regex is anchored ([.]tld$) so only the actual TLD matches —
# an unanchored pattern like ".*.(top|bid)" would false-positive on
# legitimate domains such as laptop.com or forbidden.org.
resource "cloudflare_zero_trust_gateway_policy" "dns_high_risk_tlds" {
  account_id  = local.account_id
  name        = "SASE-DNS-High-Risk-TLDs"
  description = "Block TLDs with disproportionate abuse rates (secondary control)"
  precedence  = 2
  action      = "block"
  filters     = ["dns"]

  rule_settings {
    block_page_enabled = true
    block_page_reason  = "SASE Policy: This domain is blocked for security reasons."
  }

  traffic = "dns.fqdn matches \"[.](xyz|top|gq|ml|cf|ga|tk|download|bid|date)$\""
}

# Block direct download of high-risk executable file types over HTTP.
# (Replaces the previous 'uri contains torrent/proxy' rule, which
# false-positived on any URL containing those substrings.)
resource "cloudflare_zero_trust_gateway_policy" "http_filtering" {
  account_id  = local.account_id
  name        = "SASE-HTTP-Security"
  description = "Block high-risk executable downloads"
  precedence  = 3
  action      = "block"
  filters     = ["http"]

  rule_settings {
    block_page_enabled = true
    block_page_reason  = "SASE Policy: Executable downloads are blocked by security policy."
  }

  traffic = "http.request.uri matches \"[.](exe|msi|scr|bat|ps1|vbs)$\""
}

# Routes corporate traffic through Cloudflare Gateway for logging + filtering.
# This is NOT split-tunneling — that is configured in the WARP client.
# To enable split-tunneling in WARP:
#   Zero Trust > Settings > WARP Client > Split Tunnels > "Exclude" mode
#   Add public IP ranges to bypass, leave corp ranges (10.0.0.0/8 etc.) to route through Gateway.
resource "cloudflare_zero_trust_gateway_policy" "corporate_routing" {
  account_id  = local.account_id
  name        = "SASE-Corporate-Routing"
  description = "Route corporate traffic through Gateway for DNS/HTTP inspection"
  precedence  = 4
  action      = "allow"
  filters     = ["dns", "http"]

  traffic = "dst.ip in { 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 }"
}

# Proxy endpoint for Gateway. Disabled by default — set gateway_proxy_ips to activate.
# Must use real, routable IPs owned by your organization (not TEST-NET / documentation ranges).
resource "cloudflare_zero_trust_gateway_proxy_endpoint" "sase_proxy" {
  count      = length(var.gateway_proxy_ips) > 0 ? 1 : 0
  account_id = local.account_id
  name       = "SASE-Gateway-Proxy"
  ips        = var.gateway_proxy_ips
}
