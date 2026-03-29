# --- Cloudflare Tunnel ---

resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  config_src    = "cloudflare"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

# Route the private LXC subnet through the tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "homelab_network" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  network    = "10.10.10.0/24"
}

# --- WARP Device Profile ---

resource "cloudflare_zero_trust_device_custom_profile" "homelab" {
  account_id  = var.cloudflare_account_id
  name        = "WARP homelab"
  description = "Homelab access via WARP"
  precedence  = 100
  match       = "identity.email == \"${var.cloudflare_user_email}\""
  enabled     = true

  tunnel_protocol = "wireguard"

  include = [{
    address     = "10.10.10.0/24"
    description = "Homelab private network"
  }]
}

# Local domain fallback — resolve *.alexserver.home.arpa via AdGuard in the LXC
resource "cloudflare_zero_trust_device_custom_profile_local_domain_fallback" "homelab" {
  account_id = var.cloudflare_account_id
  policy_id  = cloudflare_zero_trust_device_custom_profile.homelab.id

  domains = [{
    suffix      = "alexserver.home.arpa"
    description = "Homelab local domain"
    dns_server  = ["10.10.10.20"]
  }]
}
