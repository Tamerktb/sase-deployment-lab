output "account_id" {
  value = local.account_id
}

output "sase_sites" {
  value = {
    for k, s in var.sites : k => {
      cidr     = s.cidr
      location = s.location
    }
  }
}

output "access_policy_summary" {
  value = "Identity-based access configured for domains: ${join(", ", [for k, _ in var.sites : "https://${k}.${var.domain}"])}"
}

output "posture_status" {
  value = var.posture_checks ? "Device posture checks enabled (WARP client required)" : "Device posture checks disabled"
}

output "gateway_policies" {
  value = [
    cloudflare_zero_trust_gateway_policy.dns_filtering.name,
    cloudflare_zero_trust_gateway_policy.http_filtering.name,
    cloudflare_zero_trust_gateway_policy.split_tunnel.name,
  ]
}
