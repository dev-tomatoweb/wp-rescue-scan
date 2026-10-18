#!/usr/bin/env bash
# wp-rescue-scan.sh — read-only first-response scan of a possibly hacked WordPress site.
# It changes nothing: it reads files and the database through WP-CLI and prints a Markdown report.
#
# Usage:  bash wp-rescue-scan.sh /path/to/wordpress  > report.md
# Needs:  WP-CLI (wp) available, run as a user that can read the site files.
#
# Checks: core and plugin checksums against wordpress.org, PHP files in uploads, recently modified PHP files,
# common obfuscation/backdoor patterns, mu-plugins, administrator accounts, siteurl/home, .htaccess redirects,
# unexpected cron hooks.

set -u
WP_PATH="${1:-.}"
DAYS="${DAYS:-7}"           # "recently modified" window
MAX="${MAX:-25}"             # max lines per list
wp() { command wp --path="$WP_PATH" --skip-plugins --skip-themes --allow-root "$@" 2>/dev/null; }

ok=0; warn=0; fail=0
line()   { printf '%s\n' "$*"; }
okm()    { ok=$((ok+1));     line "- ✅ $*"; }
warnm()  { warn=$((warn+1)); line "- ⚠️ $*"; }
failm()  { fail=$((fail+1)); line "- ❌ $*"; }
section(){ line ""; line "## $*"; line ""; }
block()  { line '```'; cat; line '```'; }

[ -f "$WP_PATH/wp-config.php" ] || { echo "wp-config.php not found in $WP_PATH" >&2; exit 1; }
command -v wp >/dev/null || { echo "WP-CLI (wp) is required" >&2; exit 1; }

line "# WordPress rescue scan — $(wp option get home) — $(date -u '+%Y-%m-%d %H:%M UTC')"
line ""
line "**WordPress:** $(wp core version) · **Path:** $WP_PATH"

section "Core and plugin integrity"
if out=$(command wp --path="$WP_PATH" --skip-plugins --skip-themes --allow-root core verify-checksums 2>&1); then okm "WordPress core files match wordpress.org checksums"
else failm "Core files modified or unexpected:"; printf '%s\n' "$out" | grep -E '^(Warning|Error)' | head -n "$MAX" | block; fi
pout=$(wp plugin verify-checksums --all --format=csv 2>/dev/null | tail -n +2)
if [ -z "$pout" ]; then okm "Plugins from wordpress.org match their checksums"
else warnm "Plugin files that differ from wordpress.org (premium plugins cannot be verified):"; printf '%s\n' "$pout" | head -n "$MAX" | block; fi

section "Suspicious files"
up="$WP_PATH/wp-content/uploads"
php_up=$(find "$up" -type f \( -iname '*.php' -o -iname '*.phtml' -o -iname '*.php[0-9]' \) 2>/dev/null)
if [ -n "$php_up" ]; then failm "PHP files inside uploads (should never be there):"; printf '%s\n' "$php_up" | head -n "$MAX" | block
else okm "No PHP files in uploads"; fi
recent=$(find "$WP_PATH" -type f -name '*.php' -mtime -"$DAYS" -not -path '*/cache/*' 2>/dev/null)
if [ -n "$recent" ]; then warnm "PHP files modified in the last $DAYS days ($(printf '%s\n' "$recent" | wc -l | tr -d ' ')):"; printf '%s\n' "$recent" | head -n "$MAX" | block
else okm "No PHP files modified in the last $DAYS days"; fi
# POSIX classes only, so it works with GNU grep and busybox grep alike
php_pat='eval[[:space:]]*\([[:space:]]*(base64_decode|gzinflate|gzuncompress|str_rot13|\$_(POST|GET|REQUEST|COOKIE))|assert[[:space:]]*\([[:space:]]*\$_(POST|GET|REQUEST|COOKIE)'
js_pat='document\.write\([[:space:]]*unescape\('
hits=$( { find "$WP_PATH" -type f -name '*.php' -not -path '*/cache/*' -exec grep -lE "$php_pat" {} + ;
          find "$WP_PATH" -type f -name '*.js' -not -path '*/node_modules/*' -not -path '*/cache/*' -exec grep -lE "$js_pat" {} + ; } 2>/dev/null)
if [ -n "$hits" ]; then failm "Files containing typical obfuscation/backdoor code:"; printf '%s\n' "$hits" | head -n "$MAX" | block
else okm "No typical obfuscation/backdoor patterns found"; fi
mu="$WP_PATH/wp-content/mu-plugins"
if [ -d "$mu" ] && [ -n "$(ls -A "$mu" 2>/dev/null)" ]; then warnm "Must-use plugins present (load automatically, check they are expected):"; ls -la "$mu" | tail -n +2 | block
else okm "No must-use plugins"; fi

section "Users and settings"
admins=$(wp user list --role=administrator --fields=ID,user_login,user_email,user_registered --format=csv | tail -n +2)
n=$(printf '%s\n' "$admins" | grep -c . || true)
[ "$n" -gt 1 ] && warnm "$n administrator accounts — confirm every one is known:" || okm "$n administrator account"
printf '%s\n' "$admins" | block
home=$(wp option get home); siteurl=$(wp option get siteurl)
[ "$home" = "$siteurl" ] && okm "home and siteurl match ($home)" || warnm "home ($home) and siteurl ($siteurl) differ"
ht="$WP_PATH/.htaccess"
if [ -f "$ht" ] && grep -qiE 'RewriteCond %\{HTTP_(USER_AGENT|REFERER)\}|Redirect(Match)?\s+.*https?://' "$ht"; then
  failm ".htaccess contains referer/user-agent conditions or external redirects (typical SEO spam):"; grep -niE 'HTTP_(USER_AGENT|REFERER)|Redirect' "$ht" | head -n "$MAX" | block
else okm ".htaccess has no suspicious redirects"; fi

section "Scheduled hooks"
known='^(wp_|wc_|woocommerce|action_scheduler|delete_expired|recovery_mode|jetpack|yoast|wpseo|updraft|rocket|elementor)'
cron=$(wp cron event list --fields=hook,next_run_relative --format=csv | tail -n +2 | grep -viE "$known")
[ -n "$cron" ] && warnm "Cron hooks not from WordPress core/common plugins (check them):" && printf '%s\n' "$cron" | head -n "$MAX" | block || okm "Only common cron hooks"

section "Summary"
line "**$ok OK · $warn warnings · $fail problems**"
line ""
line "Read-only scan: nothing was changed. Next step on a hacked site: full backup, then clean from known-good copies."
[ "$fail" -gt 0 ] && exit 2 || exit 0
