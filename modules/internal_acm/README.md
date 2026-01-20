# Internal CA Certificate Management

This module helps you create and manage Internal CA certificates for AWS ACM and workstation installation.

## Quick Start

```hcl
# 1. Add module to your main.tf
module "internal_acm" {
  source = "./modules/internal_acm"

  domain               = "staging.welfan.internal"
  app_dns_zone        = "welfan.internal"
  organization_name   = "Welfan Warehouse"
}
```

```bash
# 2. Deploy with Terraform
terraform apply

# 3. Install CA on local workstation (after certificates are generated)
cd modules/internal_acm
./install-ca.sh certificates/ca-certificate.crt
```

## Overview

Instead of using self-signed certificates that browsers don't trust, this approach creates:

1. **Internal CA (Certificate Authority)** - A root certificate that acts as your own trusted authority
2. **Server Certificates** - Certificates signed by your Internal CA for your services
3. **Installation Scripts** - Automated scripts to install the CA on workstations

## Benefits

- ✅ **No browser warnings** once CA is installed on workstations
- ✅ **Professional certificate chain** with proper CA hierarchy
- ✅ **Reusable CA** for multiple services/domains
- ✅ **Compatible with AWS ACM** for load balancers, CloudFront, etc.

## Files Created

After running `terraform apply`, the module creates:

```
modules/internal_acm/
├── main.tf                   # Terraform module configuration
├── variables.tf             # Module input variables
├── outputs.tf              # Module outputs
├── versions.tf             # Provider version requirements
├── create-certificates.sh  # Script to generate all certificates (auto-executed)
├── install-ca.sh          # Script to install CA on workstations
├── README.md              # This documentation
└── certificates/          # Generated certificates (created by Terraform)
    ├── ca-private-key.pem        # CA private key (keep secure!)
    ├── ca-certificate.pem        # CA certificate (PEM format)
    ├── ca-certificate.crt        # CA certificate (CRT format for installation)
    ├── server-private-key.pem    # Server private key
    ├── server-certificate.pem    # Server certificate
    ├── server-certificate.p12    # PKCS12 bundle with password
    ├── certificate-chain.pem     # Certificate chain for ACM
    └── openssl-dynamic.conf      # Generated OpenSSL configuration
```

The certificates are automatically imported to AWS ACM and available for use with load balancers, CloudFront, etc.

## Usage

### Step 1: Use Terraform Module

Add the module to your Terraform configuration:

```hcl
module "internal_acm" {
  source = "./modules/internal_acm"

  domain               = "staging.welfan.internal"
  app_dns_zone        = "welfan.internal"
  organization_name   = "Welfan Warehouse"
  ca_validity_days    = 3650  # 10 years
  server_validity_days = 365  # 1 year
}
```

### Step 2: Deploy with Terraform

```bash
# Initialize Terraform (if not done already)
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

This will automatically:

- Generate the CA and server certificates
- Import certificates to AWS ACM
- Create the `certificates/` directory with all certificate files

### Step 3: Install CA on Workstations (After Terraform Apply)

To eliminate browser certificate warnings, install the CA certificate on each workstation that will access your internal services.

#### Automated Installation (Recommended)

The `install-ca.sh` script automatically detects your operating system and installs the CA certificate:

```bash
# After terraform apply, navigate to module directory
cd modules/internal_acm

# Install CA on local machine
./install-ca.sh certificates/ca-certificate.crt

# Or copy to remote workstation and install
scp certificates/ca-certificate.crt user@workstation:~/
scp install-ca.sh user@workstation:~/
ssh user@workstation './install-ca.sh ca-certificate.crt'
```

The script will:

- Detect your operating system (Linux, macOS, Windows)
- Install the CA certificate in the system trust store
- Provide browser-specific instructions if needed
- Show verification steps

#### Manual Installation (Alternative)

If you prefer manual installation or need to customize the process:

**Ubuntu/Debian:**

```bash
# Install CA certificate
sudo cp ca-certificate.crt /usr/local/share/ca-certificates/internal-ca.crt
sudo update-ca-certificates

# Verify installation
ls -la /usr/local/share/ca-certificates/internal-ca.crt
```

**CentOS/RHEL/Fedora:**

```bash
# Install CA certificate
sudo cp ca-certificate.crt /etc/pki/ca-trust/source/anchors/internal-ca.crt
sudo update-ca-trust

# Verify installation
ls -la /etc/pki/ca-trust/source/anchors/internal-ca.crt
```

**macOS:**

```bash
# Install CA certificate
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca-certificate.crt

# Verify installation
security find-certificate -c "Internal CA" -p /Library/Keychains/System.keychain
```

**Windows (PowerShell as Administrator):**

```powershell
# Install CA certificate
Import-Certificate -FilePath "certificates/ca-certificate.crt" -CertStoreLocation "Cert:\LocalMachine\Root"

# Or use GUI:
# 1. Double-click ca-certificate.crt
# 2. Click "Install Certificate"
# 3. Select "Local Machine" (requires admin)
# 4. Select "Trusted Root Certification Authorities"
# 5. Complete the wizard
```

**Firefox (Manual Import, any OS):**

If the automated script does not install the CA for Firefox, you can import it manually:

1. Open **Firefox** and go to **Settings → Privacy & Security**
2. Scroll to the **Certificates** section and click **View Certificates**
3. Go to the **Authorities** tab and click **Import...**
4. Select your CA certificate file (e.g., `ca-certificate.crt`)
5. Check **Trust this CA to identify websites**
6. Click **OK** and restart Firefox

If you see errors about missing `certutil` during automated install, you can install it with:

```bash
sudo apt install libnss3-tools
```

Then re-run the install script for automated Firefox import.

#### Post-Installation Verification

After installing the CA certificate:

```bash
# Navigate to module directory
cd modules/internal_acm

# Test certificate validation
openssl verify -CAfile certificates/ca-certificate.crt certificates/server-certificate.pem

# Test with curl (should show no certificate errors)
curl -v https://staging.welfan.internal

# Check system trust store (Linux)
openssl x509 -in /usr/local/share/ca-certificates/internal-ca.crt -text -noout
```

**Browser Testing:**

1. Restart your browser after CA installation
2. Clear browser cache if you still see certificate errors
3. Visit `https://staging.welfan.internal`
4. Should see a green lock icon (no certificate warnings)

## Certificate Renewal

Certificates have expiration dates and need to be renewed before they expire:

| Certificate Type   | Default Validity                      | Renewal Frequency |
| ------------------ | ------------------------------------- | ----------------- |
| CA Certificate     | 10 years (`ca_validity_days = 3650`)  | Every 10 years    |
| Server Certificate | 1 year (`server_validity_days = 365`) | Every year        |

### Check Certificate Expiration

Before renewing, check the current certificate expiration dates:

```bash
# Check CA certificate expiration
openssl x509 -in certificates/ca-certificate.pem -noout -dates

# Check Server certificate expiration
openssl x509 -in certificates/server-certificate.pem -noout -dates

# Check AWS ACM certificate expiration
aws acm describe-certificate --certificate-arn <YOUR_ACM_ARN> --query 'Certificate.NotAfter'
```

### Renewal Scenarios

#### Scenario 1: Server Certificate Expired (CA Still Valid)

If only the **server certificate** has expired but the **CA certificate** is still valid:

```bash
# Step 1: Backup old certificates
cp -r certificates/ certificates_backup_$(date +%Y%m%d)/

# Step 2: Remove old server certificates (keep CA!)
rm certificates/server-*.pem
rm certificates/server-*.p12
rm certificates/certificate-chain.pem

# Step 3: Taint only the server certificate resources to force recreation
terraform taint 'module.internal_acm.null_resource.create_certificates'
terraform taint 'module.internal_acm.aws_acm_certificate.this'
terraform taint 'module.internal_acm.aws_acm_certificate.virginia'

# Step 4: Apply to regenerate server certificates
terraform apply
```

**Note:** Since the CA certificate remains the same, you do NOT need to reinstall the CA on workstations.

#### Scenario 2: CA Certificate Expired (Full Renewal Required)

If the **CA certificate** has expired, you need to regenerate everything:

```bash
# Step 1: Backup old certificates
cp -r certificates/ certificates_backup_$(date +%Y%m%d)/

# Step 2: Remove ALL old certificates
rm -rf certificates/

# Step 3: Taint all certificate resources
terraform taint 'module.internal_acm.null_resource.create_certificates'
terraform taint 'module.internal_acm.aws_acm_certificate.this'
terraform taint 'module.internal_acm.aws_acm_certificate.virginia'

# Step 4: Apply to regenerate all certificates
terraform apply

# Step 5: IMPORTANT - Reinstall CA on ALL workstations
./install-ca.sh certificates/ca-certificate.crt
```

⚠️ **Important:** When the CA certificate is renewed, you MUST reinstall the new CA certificate on **ALL workstations** that access your internal services. Otherwise, browsers will show certificate warnings again.

#### Scenario 3: Proactive Renewal (Before Expiration)

It's recommended to renew certificates **before** they expire to avoid service disruption:

```bash
# Set a reminder 30 days before expiration
# Check expiration date
openssl x509 -in certificates/server-certificate.pem -noout -enddate

# If expiring soon, follow Scenario 1 or 2 based on which certificate is expiring
```

### Post-Renewal Verification

After renewing certificates:

```bash
# Verify new certificate dates
openssl x509 -in certificates/server-certificate.pem -noout -dates
openssl x509 -in certificates/ca-certificate.pem -noout -dates

# Verify certificate chain
openssl verify -CAfile certificates/ca-certificate.pem certificates/server-certificate.pem

# Test connection
curl -v https://staging.welfan.internal

# Verify AWS ACM import
aws acm describe-certificate --certificate-arn <YOUR_ACM_ARN>
```

### Renewal Checklist

- [ ] Check which certificate is expiring (CA or Server)
- [ ] Backup existing certificates
- [ ] Remove old certificate files
- [ ] Run `terraform apply` to regenerate
- [ ] Verify new certificate dates
- [ ] If CA was renewed: Reinstall CA on all workstations
- [ ] Test browser access (no certificate warnings)
- [ ] Update any services using the old certificates
- [ ] Set reminder for next renewal
