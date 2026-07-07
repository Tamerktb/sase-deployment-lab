resource "cloudflare_zero_trust_access_policy" "sase_policies" {
  for_each = {
    "admin"         = "https://admin.${var.domain}"
    "internal-wiki" = "https://wiki.${var.domain}"
    "monitoring"    = "https://monitor.${var.domain}"
    "jenkins"       = "https://jenkins.${var.domain}"
  }

  account_id = local.account_id
  name       = "SASE - Allow-${each.key}"
  decision   = "allow"

  include {
    email_domain = var.allowed_email_domains
  }

  require {
    device_posture = var.posture_checks ? ["device_posture"] : []
  }
}

resource "cloudflare_zero_trust_access_application" "sase_apps" {
  for_each = {
    "admin"         = "https://admin.${var.domain}"
    "internal-wiki" = "https://wiki.${var.domain}"
    "monitoring"    = "https://monitor.${var.domain}"
    "jenkins"       = "https://jenkins.${var.domain}"
  }

  account_id       = local.account_id
  name             = "SASE - ${each.key}"
  domain           = each.value
  type             = "self_hosted"
  session_duration = "24h"

  policies = [
    cloudflare_zero_trust_access_policy.sase_policies[each.key].id,
  ]
}

resource "cloudflare_zero_trust_access_group" "sase_groups" {
  account_id = local.account_id
  name       = "SASE-Engineering"

  include {
    email_domain = var.allowed_email_domains
  }

  require {
    geo = ["JO", "AE", "DE", "US"]
  }
}

resource "cloudflare_zero_trust_access_service_token" "sase_automation" {
  account_id = local.account_id
  name       = "sase-automation-token"
}
