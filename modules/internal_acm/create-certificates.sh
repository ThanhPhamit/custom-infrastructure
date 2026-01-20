#!/bin/bash

# Script to create Internal CA and server certificates using OpenSSL
# This script will create certificates that can be imported into AWS ACM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read domain from environment or use default
DOMAIN="${TF_VAR_domain:-welfan.internal}"
ORGANIZATION="${TF_VAR_organization:-Welfan Internal Organization}"

# Use custom output path if provided, otherwise use default
if [ -n "$TF_VAR_cert_output_path" ]; then
    # If absolute path, use as is; if relative, make it relative to script dir
    if [[ "$TF_VAR_cert_output_path" = /* ]]; then
        CERTS_DIR="$TF_VAR_cert_output_path"
    else
        CERTS_DIR="$SCRIPT_DIR/$TF_VAR_cert_output_path"
    fi
else
    # Create a unique directory name based on domain (replace dots with underscores)
    DOMAIN_SAFE=$(echo "$DOMAIN" | sed 's/\./_/g')
    CERTS_DIR="$SCRIPT_DIR/certificates/$DOMAIN_SAFE"
fi

CONFIG_FILE="$SCRIPT_DIR/openssl-ca.conf"

# Certificate validity periods (in days)
CA_VALIDITY_DAYS="${TF_VAR_ca_validity_days:-3650}"        # 10 years default
SERVER_VALIDITY_DAYS="${TF_VAR_server_validity_days:-365}" # 1 year default

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Creating Internal CA and Server Certificates...${NC}"
echo -e "${YELLOW}Base Domain: $DOMAIN${NC}"
echo -e "${YELLOW}Organization: $ORGANIZATION${NC}"
echo -e "${YELLOW}CA Validity: $CA_VALIDITY_DAYS days${NC}"
echo -e "${YELLOW}Server Cert Validity: $SERVER_VALIDITY_DAYS days${NC}"
echo -e "${YELLOW}Certificate Output Directory: $CERTS_DIR${NC}"

# Create certificates directory
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# Create dynamic OpenSSL config
cat > openssl-dynamic.conf << EOF
# OpenSSL configuration file for Internal CA

[req]
default_bits = 4096
prompt = no
distinguished_name = ca_distinguished_name
x509_extensions = ca_extensions

[ca_distinguished_name]
C = VN
O = $ORGANIZATION
CN = $ORGANIZATION Root CA

[ca_extensions]
basicConstraints = critical,CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always

[server_req]
default_bits = 2048
prompt = no
distinguished_name = server_distinguished_name
req_extensions = server_extensions

[server_distinguished_name]
C = VN
O = $ORGANIZATION
CN = *.$DOMAIN

[server_extensions]
basicConstraints = CA:FALSE
keyUsage = critical, keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.$DOMAIN
DNS.2 = $DOMAIN
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = 10.0.0.1
EOF

CONFIG_FILE="openssl-dynamic.conf"

# Step 1: Create CA private key
echo -e "${YELLOW}Step 1: Creating CA private key...${NC}"
if [ ! -f "ca-private-key.pem" ]; then
    openssl genrsa -out ca-private-key.pem 4096
    chmod 600 ca-private-key.pem
    echo -e "${GREEN}✓ CA private key created${NC}"
else
    echo -e "${YELLOW}✓ CA private key already exists${NC}"
fi

# Step 2: Create CA certificate (self-signed)
echo -e "${YELLOW}Step 2: Creating CA certificate...${NC}"
if [ ! -f "ca-certificate.pem" ]; then
    openssl req -new -x509 -key ca-private-key.pem -out ca-certificate.pem -days "$CA_VALIDITY_DAYS" -config "$CONFIG_FILE"
    echo -e "${GREEN}✓ CA certificate created (valid for $CA_VALIDITY_DAYS days)${NC}"
else
    echo -e "${YELLOW}✓ CA certificate already exists${NC}"
fi

# Step 3: Create server private key
echo -e "${YELLOW}Step 3: Creating server private key...${NC}"
if [ ! -f "server-private-key.pem" ]; then
    openssl genrsa -out server-private-key.pem 2048
    chmod 600 server-private-key.pem
    echo -e "${GREEN}✓ Server private key created${NC}"
else
    echo -e "${YELLOW}✓ Server private key already exists${NC}"
fi

# Step 4: Create server certificate signing request (CSR)
echo -e "${YELLOW}Step 4: Creating server CSR...${NC}"
openssl req -new -key server-private-key.pem -out server.csr -config "$CONFIG_FILE" -reqexts server_extensions

# Step 5: Sign server certificate with CA
echo -e "${YELLOW}Step 5: Signing server certificate with CA...${NC}"
openssl x509 -req -in server.csr -CA ca-certificate.pem -CAkey ca-private-key.pem -CAcreateserial \
    -out server-certificate.pem -days "$SERVER_VALIDITY_DAYS" -extensions server_extensions -extfile "$CONFIG_FILE"

# Step 6: Create certificate chain
echo -e "${YELLOW}Step 6: Creating certificate chain...${NC}"
cat server-certificate.pem ca-certificate.pem > certificate-chain.pem

# Step 7: Convert certificates to different formats
echo -e "${YELLOW}Step 7: Converting certificates to different formats...${NC}"

# Convert CA cert to CRT format for easier installation
openssl x509 -in ca-certificate.pem -out ca-certificate.crt

# Create PKCS12 bundle for some applications
openssl pkcs12 -export -out server-certificate.p12 \
    -inkey server-private-key.pem \
    -in server-certificate.pem \
    -certfile ca-certificate.pem \
    -password pass:changeme

# Cleanup
rm -f server.csr ca-certificate.srl

echo -e "${GREEN}✓ All certificates created successfully!${NC}"
echo ""
echo -e "${YELLOW}Generated files:${NC}"
echo "  📁 $CERTS_DIR/"
echo "  ├── 🔐 ca-private-key.pem       (CA private key - keep secure!)"
echo "  ├── 📜 ca-certificate.pem       (CA certificate - PEM format)"
echo "  ├── 📜 ca-certificate.crt       (CA certificate - CRT format for installation)"
echo "  ├── 🔐 server-private-key.pem   (Server private key)"
echo "  ├── 📜 server-certificate.pem   (Server certificate)"
echo "  ├── 📜 certificate-chain.pem    (Certificate chain for ACM)"
echo "  └── 📦 server-certificate.p12   (PKCS12 bundle, password: changeme)"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Import certificates to AWS ACM using:"
echo "   - Private Key: server-private-key.pem"
echo "   - Certificate: server-certificate.pem"
echo "   - Certificate Chain: ca-certificate.pem"
echo ""
echo "2. Install CA on workstations using: ./install-ca.sh ca-certificate.crt"
echo ""
echo -e "${RED}Important: Keep ca-private-key.pem secure and backed up!${NC}"
