# WordPress rescue scan — http://shop.example.test — 2026-10-18 18:56 UTC

**WordPress:** 7.1.3 · **Path:** /var/www/html

## Core and plugin integrity

- ❌ Core files modified or unexpected:
```
Warning: File doesn't verify against checksum: wp-includes/functions.php
Warning: File should not exist: wp-config-docker.php
Error: WordPress installation doesn't verify against checksums.
```
- ✅ Plugins from wordpress.org match their checksums

## Suspicious files

- ❌ PHP files inside uploads (should never be there):
```
/var/www/html/wp-content/uploads/2026/10/cache.php
```
- ⚠️ PHP files modified in the last 7 days (4):
```
/var/www/html/wp-config.php
/var/www/html/wp-includes/functions.php
/var/www/html/wp-content/mu-plugins/loader.php
/var/www/html/wp-content/uploads/2026/10/cache.php
```
- ❌ Files containing typical obfuscation/backdoor code:
```
/var/www/html/wp-content/uploads/2026/10/cache.php
```
- ⚠️ Must-use plugins present (load automatically, check they are expected):
```
drwxr-xr-x    2 33       33            4096 Oct 18 18:56 .
drwxr-xr-x    7 33       33            4096 Oct 18 18:56 ..
-rw-r--r--    1 33       33              29 Oct 18 18:56 loader.php
```

## Users and settings

- ⚠️ 2 administrator accounts — confirm every one is known:
```
1,owner,owner@example.test,"2026-10-18 18:56:29"
2,wp_support,support@example.test,"2026-10-18 18:56:30"
```
- ✅ home and siteurl match (http://shop.example.test)
- ❌ .htaccess contains referer/user-agent conditions or external redirects (typical SEO spam):
```
2:RewriteCond %{HTTP_REFERER} google\. [NC]
```

## Scheduled hooks

- ⚠️ Cron hooks not from WordPress core/common plugins (check them):
```
sys_update_check_hook,now
```

## Summary

**2 OK · 4 warnings · 4 problems**

Read-only scan: nothing was changed. Next step on a hacked site: full backup, then clean from known-good copies.
