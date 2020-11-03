#!/bin/bash
groupadd www_data
useradd www_data -g www_data --shell=/sbin/nologin -d /var/lib/nginx
chown -R www_data:www_data /var/lib/nginx
sed -i 's|^\s*user\s.*$|user www_data www_data;|g' /etc/nginx/nginx.conf
systemctl enable nginx