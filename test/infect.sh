#!/bin/sh
# Simulated, harmless infection for testing the scanner. Nothing here executes real malware.
set -e
cd /var/www/html
wp core install --url=http://shop.example.test --title=Demo --admin_user=owner --admin_email=owner@example.test --skip-email >/dev/null
mkdir -p wp-content/uploads/2026/10 wp-content/mu-plugins
printf '<?php /* simulated backdoor for tests */ if(false){ eval(base64_decode("ZWNobyAndGVzdCc7")); }\n' > wp-content/uploads/2026/10/cache.php
printf '\n// injected test line\n' >> wp-includes/functions.php
printf '<?php /* simulated loader */\n' > wp-content/mu-plugins/loader.php
wp user create wp_support support@example.test --role=administrator >/dev/null
printf 'RewriteEngine On\nRewriteCond %%{HTTP_REFERER} google\\. [NC]\nRewriteRule ^(.*)$ https://spam.example.invalid/ [R=302,L]\n' > .htaccess
wp cron event schedule sys_update_check_hook now hourly >/dev/null
echo infected
