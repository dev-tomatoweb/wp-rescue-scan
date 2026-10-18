# wp-rescue-scan

A **read-only first-response scan** for a WordPress site you suspect has been hacked.
It uses WP-CLI, changes nothing, and prints a Markdown report of what to look at first.

```bash
curl -O https://raw.githubusercontent.com/dev-tomatoweb/wp-rescue-scan/main/wp-rescue-scan.sh
bash wp-rescue-scan.sh /path/to/wordpress > report.md
```

Requires [WP-CLI](https://wp-cli.org/). Exit code `0` = nothing alarming, `2` = at least one problem found.

## What it checks

| Area | Checks |
|---|---|
| Integrity | WordPress core and wordpress.org plugins against official checksums |
| Files | PHP files inside `uploads/`, PHP files modified in the last N days, common obfuscation/backdoor patterns (`eval(base64_decode(...))`, `assert($_POST...)`, `document.write(unescape(...))`), must-use plugins |
| Users & settings | administrator accounts, `home`/`siteurl` mismatch, `.htaccess` referer/user-agent redirects (SEO spam) |
| Scheduled hooks | cron hooks that don't belong to WordPress core or common plugins |

## Tested against a simulated infection

[`test/`](test/) starts WordPress + MySQL in Docker and plants a **harmless, simulated** infection:
a PHP "backdoor" in uploads, a modified core file, a must-use plugin, a hidden administrator,
an `.htaccess` referer redirect and an unknown cron hook. The scan flags all six:

```
- ❌ Core files modified or unexpected:
  Warning: File doesn't verify against checksum: wp-includes/functions.php
- ❌ PHP files inside uploads (should never be there): wp-content/uploads/2026/10/cache.php
- ❌ Files containing typical obfuscation/backdoor code: wp-content/uploads/2026/10/cache.php
- ⚠️ Must-use plugins present (load automatically, check they are expected)
- ⚠️ 2 administrator accounts — confirm every one is known
- ❌ .htaccess contains referer/user-agent conditions or external redirects (typical SEO spam)
- ⚠️ Cron hooks not from WordPress core/common plugins: sys_update_check_hook
```

After cleaning, the same site scans clean. Full report: [`sample-report.md`](sample-report.md).

```bash
cd test
export LAB_DB_PASS=$(openssl rand -hex 16)   # random, lab only
docker compose -p wprescue up -d db wordpress
docker compose -p wprescue run --rm cli "sh /infect.sh && bash /scan/wp-rescue-scan.sh /var/www/html"
docker compose -p wprescue down -v
```

## What it is not

A scan is not a cleanup. On a hacked site: take a full backup first, then restore core and plugins from
known-good copies, remove what doesn't belong, rotate passwords and salts, and find how the attacker got in.

## License

MIT — Marco Perricone (tomatoweb)
