#!/usr/bin/env bash
# Darkly recon: map the attack surface of the target web app.
# Usage: ./recon/recon.sh [base_url]   (default http://localhost:4942)
set -u
BASE="${1:-http://localhost:4942}"
echo "=== Target: $BASE ==="

echo; echo "== Server headers =="
curl -sSI -m 10 "$BASE/" | sed 's/^/  /'

echo; echo "== Home page: title, forms, links, comments =="
HTML=$(curl -sS -m 10 "$BASE/")
echo "$HTML" | grep -ioE '<title>[^<]*</title>' | sed 's/^/  title: /'
echo "$HTML" | grep -ioE '<form[^>]*>' | sed 's/^/  form: /'
echo "$HTML" | grep -ioE 'action="[^"]*"' | sort -u | sed 's/^/  action: /'
echo "$HTML" | grep -ioE 'href="[^"]*"' | sort -u | sed 's/^/  link: /' | head -60
echo "$HTML" | grep -ioE '<!--.*-->' | sed 's/^/  comment: /'

echo; echo "== Common files =="
for p in robots.txt sitemap.xml .htaccess .git/HEAD .svn/entries \
         phpinfo.php info.php config.php backup.zip index.php.bak \
         admin/ administrator/ login.php signin signup upload.php \
         search search.php .well-known/security.txt readme.html \
         CHANGELOG.txt composer.json package.json .env; do
  code=$(curl -sS -m 8 -o /dev/null -w "%{http_code}" "$BASE/$p")
  [ "$code" != "404" ] && [ "$code" != "000" ] && printf "  %-28s %s\n" "$p" "$code"
done

echo; echo "== Cookies set by / =="
curl -sS -m 10 -i "$BASE/" | grep -i '^set-cookie:' | sed 's/^/  /'
echo; echo "Done."
