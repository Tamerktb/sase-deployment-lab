# Scenario 1: Basic Identity-Based Access

**Objective:** Verify that users can access SASE-protected applications after authenticating via Cloudflare Zero Trust.

## Topology
```
  User ──► Cloudflare Zero Trust ──► Access Policy ──► Internal App
            (Identity Check)            (Allow/Deny)
```

## Steps

### 1. Configure Cloudflare Access
```bash
# Apply Terraform to create Access applications
cd terraform
terraform apply -var="cloudflare_api_token=$CF_TOKEN" -var="zone_id=$ZONE_ID"
```

### 2. Connect via WARP Client
```bash
warp-cli register
warp-cli connect
```

### 3. Access Internal Application
Open a browser and navigate to:
```
https://admin.sase.example.com
```

You should be redirected to Cloudflare's login page. Authenticate with your email (domain: @example.com).

### 4. Verify Policy Enforcement
```bash
# Check WARP connection status
warp-cli status

# Verify session in Cloudflare dashboard
# Go to Zero Trust > Access > Monitoring
```

## Expected Results
- [ ] User is prompted for SSO/login
- [ ] Only @example.com email domains are allowed
- [ ] Access is granted to the application
- [ ] Session persists for 24 hours (configurable)

## Troubleshooting
- Ensure WARP client is connected to your Cloudflare team
- Verify the Access policy includes the user's email domain
- Check Cloudflare Tunnel is running on the target server
