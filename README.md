## Usage Instructions

1. **Prepare Your Server**

   - Ensure you have a **fresh installation of Debian 10**.
   - Make sure your domain's DNS records are correctly pointed to your server's **public IP address**.

2. **Update Configurable Variables (Optional)**

   - Open the script in a text editor to modify default variables if desired:
     ```bash
     nano wordpress_install_nginx.sh
     ```
   - Modify variables like `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DOMAIN`, and `EMAIL` at the top of the script.

3. **Save the Script**

   - After making any changes, save and exit the editor (in Nano, press `CTRL + O` to save and `CTRL + X` to exit).

4. **Make the Script Executable**

   ```bash
   chmod +x wordpress_install_nginx.sh
   ```

5. **Run the Script**

   ```bash
   sudo ./wordpress_install_nginx.sh
   ```

6. **Follow Prompts**

   - The script may prompt you for:
     - **WordPress Database Name**: Press `Enter` to accept the default or enter a custom name.
     - **WordPress Database User**: Press `Enter` to accept the default or enter a custom username.
     - **WordPress Database Password**: Press `Enter` to accept the default or enter a strong password.
     - **Domain Name**: Enter your actual domain (e.g., `yourdomain.com`).
     - **Email for SSL Notifications**: Enter a valid email address for SSL certificate notifications.
     - **MariaDB Root Password**: Enter the root password for MariaDB. If MariaDB is being secured for the first time, follow the prompts to set the root password.

7. **Complete WordPress Setup**

   - Once the script completes, open your web browser and navigate to `https://yourdomain.com`.
   - You should see the WordPress installation page where you can finalize the setup by choosing your site title, admin username, password, and email.

---

## Additional Recommendations and Best Practices

### **1. Security Enhancements**

- **Disable Unnecessary Services**: Ensure that only essential services are running on your server.
  
- **Regular Updates**: Keep your server and all installed packages up-to-date to protect against vulnerabilities.
  
- **Strong Passwords**: Use strong, unique passwords for all users and services.
  
- **Limit SSH Access**: Consider changing the default SSH port and disabling root login via SSH for added security.

### **2. Backups**

- **Regular Backups**: Implement a regular backup strategy for your WordPress files and database to prevent data loss.
  
- **Offsite Storage**: Store backups in a secure, offsite location.

### **3. Performance Optimization**

- **Caching**: Implement caching mechanisms like Redis or Memcached to improve website performance.
  
- **Content Delivery Network (CDN)**: Use a CDN to distribute your content globally for faster load times.

### **4. Monitoring and Logging**

- **Monitor Server Health**: Use monitoring tools like `htop`, `netdata`, or other monitoring solutions to keep an eye on server resources.
  
- **Log Management**: Regularly review Nginx and PHP-FPM logs to identify and address issues promptly.

### **5. Database Optimization**

- **Regular Maintenance**: Optimize your MariaDB database regularly to maintain performance.
  
- **Use a Dedicated Database User**: Ensure that the database user has only the necessary privileges.

### **6. SSL Certificate Renewal**

- **Manual Renewal Check**: Although Certbot sets up automatic renewals, periodically check the renewal process with:
  
  ```bash
  certbot renew --dry-run
  ```
  
- **Email Notifications**: Ensure that the email provided during SSL setup is monitored for renewal alerts.

### **7. Scaling Considerations**

- **Load Balancing**: For high-traffic websites, consider setting up load balancers to distribute traffic effectively.
  
- **Database Replication**: Implement database replication for better reliability and performance.

---

## Troubleshooting Tips

1. **Check Logs**

   - **Installation Log**: `/var/log/wordpress_install.log`
   - **Nginx Logs**:
     - Access Log: `/var/log/nginx/yourdomain.com_access.log`
     - Error Log: `/var/log/nginx/yourdomain.com_error.log`
   - **PHP-FPM Logs**: `/var/log/php${PHP_VERSION}-fpm.log`
   - **MariaDB Logs**: `/var/log/mysql/error.log`

2. **Verify Services**

   - **Nginx**:
     ```bash
     systemctl status nginx
     ```
   - **PHP-FPM**:
     ```bash
     systemctl status php${PHP_VERSION}-fpm
     ```
   - **MariaDB**:
     ```bash
     systemctl status mariadb
     ```

3. **Test PHP Processing**

   - Create a `info.php` file to test PHP processing:
     ```bash
     echo "<?php phpinfo(); ?>" > /var/www/html/info.php
     ```
   - Navigate to `http://yourdomain.com/info.php` to verify PHP is working correctly. **Remember to delete this file after testing**:
     ```bash
     rm /var/www/html/info.php
     ```

4. **Firewall Issues**

   - Ensure that `ufw` allows necessary traffic:
     ```bash
     ufw status
     ```
   - Adjust firewall settings if necessary:
     ```bash
     ufw allow 'Nginx Full'
     ufw allow OpenSSH
     ufw reload
     ```

5. **SSL Certificate Issues**

   - Verify SSL certificate status:
     ```bash
     certbot certificates
     ```
   - Renew certificates manually if needed:
     ```bash
     certbot renew
     ```

6. **Database Connection Issues**

   - Verify that WordPress can connect to the database using the credentials provided.
   - Test MariaDB connection:
     ```bash
     mysql -u wp_user -p -h localhost wordpress_db
     ```
