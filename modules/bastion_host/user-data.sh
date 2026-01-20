#!/bin/bash

# Update system
sudo dnf update -y

# Install only PostgreSQL client (no server components)
sudo dnf install -y postgresql-client

# Install other useful tools
sudo dnf install -y \
    htop \
    nano \
    vim \
    telnet \
    wget \
    curl \
    git \
    net-tools \
    traceroute

# Create log file to confirm installation
echo "Bastion host setup completed at $(date)" | sudo tee -a /var/log/bastion-setup.log
echo "PostgreSQL client version:" | sudo tee -a /var/log/bastion-setup.log
psql --version | sudo tee -a /var/log/bastion-setup.log

echo "PostgreSQL client installation completed successfully!" | sudo tee -a /var/log/bastion-setup.log
echo "Use 'psql --version' to verify installation" | sudo tee -a /var/log/bastion-setup.log
echo "Use 'psql -h <host> -p <port> -U <username> -d <database>' to connect" | sudo tee -a /var/log/bastion-setup.log