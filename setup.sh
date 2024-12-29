#!/usr/bin/env bash

###############################################################################
# Enhanced WordPress Installation Script for Debian 10 with Nginx Setup
# and SSL Configuration using Certbot
###############################################################################

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# -------------------- CONFIGURABLE VARIABLES --------------------
# These variables can be modified as needed.
DB_NAME="wordpress_db"
DB_USER="wp_user"
DB_PASSWORD="wp_pass_123"

WP_DIR="/var/www/html"

DOMAIN="example.com"          # Replace with your domain
EMAIL="admin@example.com"     # Replace with your email for SSL notifications

NGINX_CONF_DIR="/etc/nginx/sites-available"

LOG_FILE="/var/log/wordpress_install.log"

# PHP Version (default to 8.0; adjust if necessary)
PHP_VERSION="8.0"

# ---------------------------------------------------------------

# -------------------- FUNCTION DEFINITIONS --------------------

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" | tee -a "$LOG_FILE"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt for input if variable is not set
prompt_if_empty() {
    local var_name=$1
    local prompt_message=$2
    local default_value=$3

    if [ -z "${!var_name}" ]; then
        read -rp "$prompt_message [$default_value]: " input
        if [ -z "$input" ]; then
            export "$var_name"="$default_value"
        else
            export "$var_name"="$input"
        fi
    fi
}

# Function to handle errors
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to install PHP from Sury repository
install_php() {
    log "Installing PHP from Sury repository..."
    apt-get install -y apt-transport-https lsb-release ca-certificates curl
    curl -fsSL https://packages.sury.org/php/apt.gpg | apt-key add - || error_exit "Failed to add Sury GPG key."
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
    apt-get update -y
    apt-get install -y "php${PHP_VERSION}-fpm" "php${PHP_VERSION}-mysql" "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-curl" "php${PHP_VERSION}-gd" "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-xml" "php${PHP_VERSION}-xmlrpc" "php${PHP_VERSION}-zip" || error_exit "Failed to install PHP."
    log "PHP ${PHP_VERSION} installed successfully."
}

# Function to configure UFW firewall
configure_firewall() {
    log "Configuring UFW firewall..."
    apt-get install -y ufw || error_exit "Failed to install UFW."
    ufw allow 'Nginx Full' || error_exit "Failed to allow Nginx Full through UFW."
    ufw allow OpenSSH || error_exit "Failed to allow OpenSSH through UFW."
    echo "y" | ufw enable || error_exit "Failed to enable UFW."
    log "UFW firewall configured."
}

# Function to install necessary dependencies
install_dependencies() {
    log "Installing necessary packages..."
    apt-get install -y nginx mariadb-server curl wget unzip git || error_exit "Failed to install necessary packages."
    log "Necessary packages installed."
}

# Function to secure MariaDB
secure_mariadb() {
    log "Securing MariaDB..."
    mysql_secure_installation <<EOF

y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
y
y
y
y
EOF
    log "MariaDB secured."
}

# Function to check Debian version
check_debian_version() {
    local version
    version=$(lsb_release -rs)
    if [[ "$version" != "10" ]]; then
        error_exit "This script is designed for Debian 10. Detected version: $version"
    fi
}

# Function to setup MariaDB database and user
setup_database() {
    log "Setting up MariaDB database and user..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    log "Database and user for WordPress created."
}

# Function to download and configure WordPress
install_wordpress() {
    log "Downloading WordPress..."
    cd /tmp
    wget https://wordpress.org/latest.tar.gz || error_exit "Failed to download WordPress."
    tar -xzf latest.tar.gz || error_exit "Failed to extract WordPress."
    log "WordPress downloaded and extracted."

    log "Configuring WordPress in ${WP_DIR}..."
    rm -rf "${WP_DIR}"/* || error_exit "Failed to remove existing files in ${WP_DIR}."
    cp -r wordpress/* "${WP_DIR}/" || error_exit "Failed to copy WordPress files."
    log "WordPress files copied to ${WP_DIR}."
}

# Function to set file permissions
set_permissions() {
    log "Setting file permissions..."
    chown -R www-data:www-data "${WP_DIR}" || error_exit "Failed to set ownership."
    find "${WP_DIR}" -type d -exec chmod 755 {} \; || error_exit "Failed to set directory permissions."
    find "${WP_DIR}" -type f -exec chmod 644 {} \; || error_exit "Failed to set file permissions."
    log "File permissions set."
}

# Function to configure wp-config.php
configure_wp_config() {
    log "Configuring wp-config.php..."
    cd "${WP_DIR}" || error_exit "Failed to navigate to ${WP_DIR}."
    cp wp-config-sample.php wp-config.php || error_exit "Failed to copy wp-config.php."

    # Insert database credentials
    sed -i "s/database_name_here/${DB_NAME}/" wp-config.php
    sed -i "s/username_here/${DB_USER}/" wp-config.php
    sed -i "s/password_here/${DB_PASSWORD}/" wp-config.php

    # Generate and insert unique authentication keys and salts
    SALT_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    if [ -z "$SALT_KEYS" ]; then
        error_exit "Failed to retrieve salt keys."
    fi

    # Remove existing placeholder keys
    sed -i "/AUTH_KEY/d" wp-config.php
    sed -i "/SECURE_AUTH_KEY/d" wp-config.php
    sed -i "/LOGGED_IN_KEY/d" wp-config.php
    sed -i "/NONCE_KEY/d" wp-config.php
    sed -i "/AUTH_SALT/d" wp-config.php
    sed -i "/SECURE_AUTH_SALT/d" wp-config.php
    sed -i "/LOGGED_IN_SALT/d" wp-config.php
    sed -i "/NONCE_SALT/d" wp-config.php

    # Append the new salt keys
    echo "$SALT_KEYS" >> wp-config.php
    log "wp-config.php configured with database credentials and salts."
}

# Function to configure Nginx server block
configure_nginx() {
    log "Configuring Nginx for domain ${DOMAIN}..."
    local NGINX_CONF="${NGINX_CONF_DIR}/${DOMAIN}.conf"

    cat > "$NGINX_CONF" <<EOL
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN} www.${DOMAIN};

    root ${WP_DIR};
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    # Disable .git directory access
    location ~ /\.git {
        deny all;
    }

    # Disable access to wp-config.php
    location ~* /wp-config.php {
        deny all;
    }
}
EOL

    # Enable the new server block
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ || error_exit "Failed to enable Nginx server block."

    # Disable the default Nginx site if enabled
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm /etc/nginx/sites-enabled/default || error_exit "Failed to disable default Nginx site."
        log "Default Nginx site disabled."
    fi

    # Test Nginx configuration
    nginx -t || error_exit "Nginx configuration test failed."

    # Reload Nginx to apply changes
    systemctl reload nginx || error_exit "Failed to reload Nginx."
    log "Nginx configured for domain ${DOMAIN}."
}

# Function to install and configure SSL with Certbot
install_ssl() {
    log "Installing Certbot and Nginx plugin..."
    apt-get install -y certbot python3-certbot-nginx || error_exit "Failed to install Certbot."

    log "Obtaining SSL certificate for ${DOMAIN}..."
    certbot --nginx --non-interactive --agree-tos --redirect --hsts \
        -m "${EMAIL}" \
        -d "${DOMAIN}" -d "www.${DOMAIN}" || error_exit "Certbot failed to obtain SSL certificate."

    log "SSL certificate obtained and configured."
}

# Function to finalize WordPress installation
finalize_installation() {
    log "Finalizing WordPress installation..."

    # Create wp-content/uploads directory with correct permissions
    mkdir -p "${WP_DIR}/wp-content/uploads" || error_exit "Failed to create uploads directory."
    chown -R www-data:www-data "${WP_DIR}/wp-content/uploads" || error_exit "Failed to set ownership for uploads."
    chmod -R 755 "${WP_DIR}/wp-content/uploads" || error_exit "Failed to set permissions for uploads."

    log "WordPress installation is complete!"
    log "You can access your website at https://${DOMAIN}/"
}

# Function to setup automatic SSL renewal
setup_ssl_renewal() {
    log "Setting up automatic SSL certificate renewal..."
    # Certbot installs a systemd timer for renewal by default
    if systemctl list-timers | grep -q "certbot.timer"; then
        log "Certbot renewal timer is active."
    else
        systemctl enable certbot.timer || error_exit "Failed to enable Certbot timer."
        systemctl start certbot.timer || error_exit "Failed to start Certbot timer."
        log "Certbot renewal timer enabled."
    fi
}

# -------------------- MAIN SCRIPT EXECUTION --------------------

# Initialize log file
touch "$LOG_FILE" || { echo "Failed to create log file at $LOG_FILE"; exit 1; }
log "==================== Starting WordPress Installation ===================="

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root. Use sudo or switch to the root user."
fi

# Check Debian version
check_debian_version

# Prompt for configuration if variables are not set
prompt_if_empty "DB_NAME" "Enter WordPress database name" "wordpress_db"
prompt_if_empty "DB_USER" "Enter WordPress database user" "wp_user"
prompt_if_empty "DB_PASSWORD" "Enter WordPress database password" "wp_pass_123"
prompt_if_empty "DOMAIN" "Enter your domain name" "example.com"
prompt_if_empty "EMAIL" "Enter your email for SSL notifications" "admin@example.com"

# Prompt for MariaDB root password if not set
if [ -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
    read -rsp "Enter MariaDB root password: " MYSQL_ROOT_PASSWORD
    echo
fi

# Install dependencies
install_dependencies

# Install PHP
install_php

# Install and configure UFW firewall
if command_exists ufw; then
    configure_firewall
else
    log "UFW not found. Skipping firewall configuration."
fi

# Secure MariaDB
secure_mariadb

# Setup database and user
setup_database

# Install WordPress
install_wordpress

# Set file permissions
set_permissions

# Configure wp-config.php
configure_wp_config

# Configure Nginx server block
configure_nginx

# Install and configure SSL
install_ssl

# Finalize installation
finalize_installation

# Setup SSL renewal
setup_ssl_renewal

log "==================== WordPress Installation Completed Successfully ===================="

