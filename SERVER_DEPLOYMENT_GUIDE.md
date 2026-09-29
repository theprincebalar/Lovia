# Lovia Server Deployment & DNS Configuration Guide

This guide details everything needed to deploy the **Node.js REST API Backend** and **React.js Admin Panel** to your server, connect custom domains, and configure DNS.

---

## 1. Credentials Required From You

To allow pushing the code and setting up your server, please provide:

| Parameter | Example Value | Description |
| :--- | :--- | :--- |
| **Server IP Address** | `159.65.123.45` | Public IP of your Linux VPS (Ubuntu 22.04 / 24.04 recommended) |
| **SSH Username** | `root` or `ubuntu` | Server administrative user |
| **SSH Port** | `22` | Default SSH port (unless custom configured) |
| **SSH Password or Key** | `YourSecretPassword` or `.pem` key | Authentication credential to log into the server |
| **Your Domain Name** | `lovia-app.com` | Your registered domain name |

---

## 2. DNS Configuration (Required in your Domain Registrar)

Log into your DNS provider (Cloudflare, Namecheap, GoDaddy, Hostinger, AWS Route 53, etc.) and add the following two **A Records**:

| Type | Host / Name | Value / Target (IP) | TTL | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `api` | `YOUR_SERVER_IP` (e.g. 159.65.123.45) | Auto / 300s | Points `api.yourdomain.com` to the Node.js Backend API |
| **A** | `admin` | `YOUR_SERVER_IP` (e.g. 159.65.123.45) | Auto / 300s | Points `admin.yourdomain.com` to the React.js Admin Dashboard |

> **Cloudflare Note**: If using Cloudflare, you can enable the Orange Cloud (Proxied) for automatic DDoS protection and SSL.

---

## 3. Automated Server Provisioning Steps

Once we log into your server via SSH, the deployment follows these commands:

### Step 1: Install Node.js 20 & PM2
```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs nginx certbot python3-certbot-nginx
sudo npm install -g pm2
```

### Step 2: Push & Start Node.js Backend
```bash
mkdir -p /var/www/lovia-backend
# Code pushed to /var/www/lovia-backend
cd /var/www/lovia-backend
npm install --production
pm2 start server.js --name lovia-backend
pm2 save
pm2 startup
```

### Step 3: Build & Host React.js Admin Panel
```bash
mkdir -p /var/www/lovia-admin
# Code pushed to /var/www/lovia-admin
cd /var/www/lovia-admin
npm install
npm run build
```

### Step 4: Configure Nginx Reverse Proxy
Create `/etc/nginx/sites-available/lovia`:
```nginx
# 1. Node.js API (api.yourdomain.com)
server {
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    client_max_body_size 20M;
}

# 2. React Admin Panel (admin.yourdomain.com)
server {
    server_name admin.yourdomain.com;
    root /var/www/lovia-admin/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:5000/api/;
        proxy_set_header Host $host;
    }

    location /uploads/ {
        proxy_pass http://localhost:5000/uploads/;
        proxy_set_header Host $host;
    }
}
```
Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/lovia /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Secure with Free Let's Encrypt SSL
```bash
sudo certbot --nginx -d api.yourdomain.com -d admin.yourdomain.com --non-interactive --agree-tos -m your-email@example.com
```

---

## 4. Admin Panel Features

Once deployed, access `https://admin.yourdomain.com`:
- **Live Stats**: Total characters, Active online agents, Offline agents, Hidden characters.
- **Instant Controls**:
  - `Turn ON / OFF`: Instantly activate or pause any AI character.
  - `Hide / Show`: Instantly hide or show any character from the mobile app's discovery feeds.
  - `Create & Edit`: Add new AI companions with custom names, avatar photos, behavioral brain prompts, and starter greetings.
  - `Server Keys`: Update AI engine keys and voice credentials directly from the web browser without touching server files.

---

## 5. Mobile App Live Dynamic Connection

In `lib/services/api_service.dart` (or `storage_service.dart`), set:
```dart
const String backendApiUrl = 'https://api.yourdomain.com';
```
The app will dynamically fetch all characters from your server. Characters you toggle off or hide in the admin panel will instantly reflect in the app!
