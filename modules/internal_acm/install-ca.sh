#!/bin/bash

# Script to install Internal CA certificate on workstations
# Usage: ./install-ca.sh <ca-certificate-file> [custom-name]
# 
# This script automatically generates unique filenames based on certificate content
# to prevent overwriting when installing multiple CA certificates.

set -e

CA_CERT_FILE="$1"
CUSTOM_NAME="$2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$CA_CERT_FILE" ]; then
    echo -e "${RED}Usage: $0 <ca-certificate-file> [custom-name]${NC}"
    echo -e "${YELLOW}Example: $0 certificates/ca-certificate.crt${NC}"
    echo -e "${YELLOW}Example: $0 certificates/ca-certificate.crt my-company-dev${NC}"
    echo ""
    echo -e "${BLUE}The script will auto-generate a unique name from certificate content${NC}"
    echo -e "${BLUE}or you can provide a custom name as the second argument.${NC}"
    exit 1
fi

if [ ! -f "$CA_CERT_FILE" ]; then
    echo -e "${RED}Error: CA certificate file '$CA_CERT_FILE' not found!${NC}"
    exit 1
fi

# Function to extract environment/identifier from certificate CN
extract_cert_identifier() {
    local cert_file="$1"
    
    # Extract CN (Common Name) from certificate
    local cn=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed -n 's/.*CN = \([^,]*\).*/\1/p')
    
    if [ -z "$cn" ]; then
        # Fallback: use hash of certificate
        echo "ca-$(openssl x509 -in "$cert_file" -noout -hash 2>/dev/null)"
        return
    fi
    
    # Extract environment identifier from CN
    # Examples: 
    #   "Development Welfan Internal Organization Root CA" -> "dev-welfan"
    #   "Production Welfan Internal Organization Root CA" -> "prod-welfan"
    #   "Staging Welfan Internal Organization Root CA" -> "stg-welfan"
    
    local env_name=""
    local org_name=""
    
    # Detect environment
    if echo "$cn" | grep -qi "development\|develop\|dev"; then
        env_name="dev"
    elif echo "$cn" | grep -qi "production\|prod"; then
        env_name="prod"
    elif echo "$cn" | grep -qi "staging\|stg"; then
        env_name="stg"
    elif echo "$cn" | grep -qi "mockup\|mock"; then
        env_name="mockup"
    elif echo "$cn" | grep -qi "test"; then
        env_name="test"
    else
        env_name="custom"
    fi
    
    # Extract organization name (first significant word after environment)
    org_name=$(echo "$cn" | sed -E 's/(Development|Production|Staging|Mockup|Test|Internal|Organization|Root|CA)//gi' | tr -s ' ' | sed 's/^ *//;s/ *$//' | awk '{print tolower($1)}')
    
    if [ -z "$org_name" ]; then
        org_name="internal"
    fi
    
    echo "${env_name}-${org_name}"
}

# Generate unique filename for the certificate
if [ -n "$CUSTOM_NAME" ]; then
    # Use custom name provided by user
    CA_INSTALL_NAME="$CUSTOM_NAME"
else
    # Auto-generate name from certificate content
    CA_INSTALL_NAME=$(extract_cert_identifier "$CA_CERT_FILE")
fi

# Sanitize the name (remove special characters, convert to lowercase)
CA_INSTALL_NAME=$(echo "$CA_INSTALL_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

# Final filename
CA_DEST_FILENAME="internal-ca-${CA_INSTALL_NAME}.crt"

echo -e "${BLUE}Installing Internal CA certificate...${NC}"
echo -e "${YELLOW}Certificate file: $CA_CERT_FILE${NC}"
echo -e "${YELLOW}Install name: $CA_DEST_FILENAME${NC}"
echo ""

# Detect OS and install accordingly
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    
    # Ubuntu/Debian
    if command -v update-ca-certificates &> /dev/null; then
        echo -e "${YELLOW}Detected Ubuntu/Debian system${NC}"
        
        DEST_PATH="/usr/local/share/ca-certificates/$CA_DEST_FILENAME"
        
        # Check if certificate already exists
        if [ -f "$DEST_PATH" ]; then
            echo -e "${YELLOW}Certificate already exists at: $DEST_PATH${NC}"
            
            # Compare certificates
            EXISTING_HASH=$(openssl x509 -in "$DEST_PATH" -noout -hash 2>/dev/null)
            NEW_HASH=$(openssl x509 -in "$CA_CERT_FILE" -noout -hash 2>/dev/null)
            
            if [ "$EXISTING_HASH" = "$NEW_HASH" ]; then
                echo -e "${GREEN}✓ Same certificate already installed. Skipping.${NC}"
            else
                echo -e "${YELLOW}Different certificate with same name exists. Updating...${NC}"
                if [ "$EUID" -ne 0 ]; then
                    sudo cp "$CA_CERT_FILE" "$DEST_PATH"
                    sudo update-ca-certificates --fresh
                else
                    cp "$CA_CERT_FILE" "$DEST_PATH"
                    update-ca-certificates --fresh
                fi
                echo -e "${GREEN}✓ Certificate updated${NC}"
            fi
        else
            # Install new certificate
            if [ "$EUID" -ne 0 ]; then
                echo -e "${YELLOW}Need sudo privileges to install CA certificate...${NC}"
                sudo cp "$CA_CERT_FILE" "$DEST_PATH"
                sudo update-ca-certificates
            else
                cp "$CA_CERT_FILE" "$DEST_PATH"
                update-ca-certificates
            fi
            echo -e "${GREEN}✓ CA certificate installed successfully on Ubuntu/Debian${NC}"
        fi
        
        # Install for Firefox (NSS database) - Improved method
        if command -v certutil &> /dev/null; then
            echo -e "${YELLOW}Installing CA for Firefox/Chrome...${NC}"
            
            # Generate unique nickname for NSS database
            NSS_NICKNAME="Internal CA - ${CA_INSTALL_NAME}"
            
            # Find all Firefox profiles
            if [ -d ~/.mozilla/firefox ]; then
                PROFILES_FOUND=false
                for profile in ~/.mozilla/firefox/*.default* ~/.mozilla/firefox/*/; do
                    if [ -d "$profile" ] && [[ "$profile" != *"/Cache/"* ]]; then
                        profile_name=$(basename "$profile")
                        echo "  Found Firefox profile: $profile_name"
                        
                        # Try both old and new NSS database formats
                        certutil -A -n "$NSS_NICKNAME" -t "TCu,Cu,Tu" -i "$CA_CERT_FILE" -d "$profile" 2>/dev/null && echo "    ✓ Installed (old format)" || \
                        certutil -A -n "$NSS_NICKNAME" -t "TCu,Cu,Tu" -i "$CA_CERT_FILE" -d "sql:$profile" 2>/dev/null && echo "    ✓ Installed (new format)" || \
                        echo "    ✗ Failed to install in $profile_name"
                        
                        PROFILES_FOUND=true
                    fi
                done
                
                if [ "$PROFILES_FOUND" = false ]; then
                    echo "  No Firefox profiles found. Firefox may not be installed or never opened."
                fi
            else
                echo "  Firefox not found (~/.mozilla/firefox doesn't exist)"
            fi
            
            # Install for Chrome/Chromium
            if [ -d "$HOME/.pki/nssdb" ]; then
                echo "  Installing for Chrome/Chromium..."
                if certutil -A -n "$NSS_NICKNAME" -t "TCu,Cu,Tu" -i "$CA_CERT_FILE" -d "sql:$HOME/.pki/nssdb" 2>/dev/null; then
                    echo "    ✓ Chrome/Chromium certificate installed"
                else
                    echo "    ✗ Failed to install for Chrome/Chromium"
                fi
            fi
            
        else
            echo -e "${YELLOW}certutil not found. To install certificates for Firefox:${NC}"
            echo "  1. Install NSS tools: sudo apt install libnss3-tools"
            echo "  2. Run this script again"
            echo "  3. Or install manually in Firefox (see instructions below)"
        fi
    
    # CentOS/RHEL/Fedora
    elif command -v update-ca-trust &> /dev/null; then
        echo -e "${YELLOW}Detected CentOS/RHEL/Fedora system${NC}"
        
        DEST_PATH="/etc/pki/ca-trust/source/anchors/$CA_DEST_FILENAME"
        
        if [ "$EUID" -ne 0 ]; then
            echo -e "${YELLOW}Need sudo privileges to install CA certificate...${NC}"
            sudo cp "$CA_CERT_FILE" "$DEST_PATH"
            sudo update-ca-trust
        else
            cp "$CA_CERT_FILE" "$DEST_PATH"
            update-ca-trust
        fi
        
        echo -e "${GREEN}✓ CA certificate installed successfully on CentOS/RHEL/Fedora${NC}"
        
    else
        echo -e "${RED}Unsupported Linux distribution${NC}"
        echo -e "${YELLOW}Manual installation required. Add this certificate to your system's CA store.${NC}"
        exit 1
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - Always install system-wide (option 1)
    echo -e "${YELLOW}Detected macOS system${NC}"
    echo -e "${YELLOW}Installing CA certificate system-wide (requires admin password)...${NC}"
    
    # Check if certificate already exists in keychain
    CERT_CN=$(openssl x509 -in "$CA_CERT_FILE" -noout -subject 2>/dev/null | sed -n 's/.*CN = \([^,]*\).*/\1/p')
    
    if security find-certificate -c "$CERT_CN" /Library/Keychains/System.keychain &>/dev/null; then
        echo -e "${YELLOW}Certificate '$CERT_CN' may already exist. Installing anyway (will update if different)...${NC}"
    fi
    
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_CERT_FILE"
    echo -e "${GREEN}✓ CA certificate installed system-wide${NC}"
    echo -e "${BLUE}Note:${NC} You may need to restart browsers for changes to take effect."

elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows (if running in Git Bash or similar)
    echo -e "${YELLOW}Detected Windows system${NC}"
    echo -e "${YELLOW}For Windows, choose one of these installation methods:${NC}"
    echo ""
    echo -e "${BLUE}Option 1: PowerShell (Automated - Requires Admin):${NC}"
    echo "1. Open PowerShell as Administrator"
    echo "2. Run: Import-Certificate -FilePath \"$CA_CERT_FILE\" -CertStoreLocation \"Cert:\\LocalMachine\\Root\""
    echo "3. Or for current user only: Import-Certificate -FilePath \"$CA_CERT_FILE\" -CertStoreLocation \"Cert:\\CurrentUser\\Root\""
    echo ""
    echo -e "${BLUE}Option 2: GUI (Manual):${NC}"
    echo "1. Double-click on: $CA_CERT_FILE"
    echo "2. Click 'Install Certificate'"
    echo "3. Select 'Local Machine' (requires admin) or 'Current User'"
    echo "4. Select 'Place all certificates in the following store'"
    echo "5. Click 'Browse' and select 'Trusted Root Certification Authorities'"
    echo "6. Click 'Next' and 'Finish'"
    
else
    echo -e "${RED}Unsupported operating system: $OSTYPE${NC}"
    echo -e "${YELLOW}Please install the CA certificate manually:${NC}"
    echo "CA Certificate file: $CA_CERT_FILE"
    exit 1
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo -e "${BLUE}Important notes:${NC}"
echo "• You may need to restart your browser or applications"
echo "• Clear browser cache if you still see certificate errors"
echo "• Some applications may require additional configuration"
echo ""
echo -e "${YELLOW}Installed CA certificates on this system:${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -d /usr/local/share/ca-certificates ]; then
        for cert in /usr/local/share/ca-certificates/internal-ca*.crt; do
            if [ -f "$cert" ]; then
                cert_name=$(basename "$cert")
                cert_subject=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/subject=/  /')
                echo -e "${GREEN}• $cert_name${NC}"
                echo "$cert_subject"
            fi
        done
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  Run: security find-certificate -a -c 'Internal' /Library/Keychains/System.keychain"
fi
echo ""
echo -e "${YELLOW}To verify installation:${NC}"
echo "• Visit site in a browser"
echo "• Check that the certificate shows as trusted (no warnings)"
echo "• On Linux: openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt your-server-cert.pem"
echo ""
echo -e "${BLUE}Manual Firefox Installation (if needed):${NC}"
echo "1. Open Firefox → Settings → Privacy & Security"
echo "2. Scroll to 'Certificates' → Click 'View Certificates'"
echo "3. 'Authorities' tab → Click 'Import...'"
echo "4. Select: $(realpath "$CA_CERT_FILE")"
echo "5. Check ✓ 'Trust this CA to identify websites'"
echo "6. Click 'OK' → Restart Firefox"

# Display certificate information
echo ""
echo -e "${BLUE}Certificate Information:${NC}"
openssl x509 -in "$CA_CERT_FILE" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After :)"
