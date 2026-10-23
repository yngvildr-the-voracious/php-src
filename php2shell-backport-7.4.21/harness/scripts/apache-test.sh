#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Apache 2.4.6 (CentOS 7) + mod_php end-to-end check, single prefork worker so
# every request lands on the same child process.
# Usage: apache-test.sh <tree>      (uses /dak/work/<tree>/libs/libphp7.so)
set -uo pipefail
t=$1; conf=/tmp/httpd-$t.conf; log=/dak/logs/apache-$t-error.log; : > $log

cat > $conf <<EOF
ServerRoot /etc/httpd
Listen 127.0.0.1:8080
PidFile /tmp/httpd-$t.pid
LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule mime_module modules/mod_mime.so
LoadModule log_config_module modules/mod_log_config.so
# Bare container has no /etc/mime.types; only .php is served here.
TypesConfig /dev/null
LoadModule php7_module /dak/work/$t/libs/libphp7.so
User apache
Group apache
ServerName localhost
DocumentRoot /dak/www
<Directory /dak/www>
  Require all granted
</Directory>
<FilesMatch \.php$>
  SetHandler application/x-httpd-php
</FilesMatch>
ErrorLog $log
LogLevel info
StartServers 1
MinSpareServers 1
MaxSpareServers 1
ServerLimit 1
MaxRequestWorkers 1
MaxConnectionsPerChild 0
php_admin_value memory_limit 4M
php_admin_value post_max_size 16M
php_admin_value upload_max_filesize 8M
php_admin_value session.save_path /tmp
php_admin_flag display_errors on
EOF

/usr/sbin/httpd -f $conf -k start
for i in $(seq 1 50); do curl -s -o /dev/null http://127.0.0.1:8080/pid.php && break; sleep 0.2; done

U=http://127.0.0.1:8080
req() { # <label> <curl args...>  -> curl exit code, HTTP status, first 200 bytes of body
  local label=$1; shift
  local code; code=$(curl -s -o /tmp/body -w '%{http_code}' "$@"); local rc=$?
  printf '%-34s curl_exit=%-3s http=%-4s body=%s\n' "$label" "$rc" "$code" "$(tr -s '\n' ' ' < /tmp/body | cut -c1-200)"
}
pid() { curl -s $U/pid.php; }

echo "### Apache mod_php: $t ($(/dak/work/$t/sapi/cli/php -n -r 'echo PHP_VERSION;'))"
p1=$(pid); p2=$(pid)
echo "worker pid before: $p1 / $p2 (same child: $([ "$p1" = "$p2" ] && echo yes || echo no))"

head -c 6291456 /dev/zero | tr '\0' 'x' | sed 's/^/a=/' > /tmp/big
req "OOM while parsing 6MB POST" -X POST --data-binary @/tmp/big -H 'Content-Type: application/x-www-form-urlencoded' $U/ran.php
p3=$(pid)
echo "worker pid after parse-OOM: $p3 -> $([ "$p3" = "$p1" ] && echo 'SAME worker kept serving' || echo 'worker replaced (old one exited)')"

req "OOM inside script" $U/oom.php
p4=$(pid)
echo "worker pid after script-OOM: $p4 -> $([ "$p4" = "$p3" ] && echo 'SAME worker kept serving' || echo 'worker replaced (old one exited)')"

echo "--- functional checks on the (possibly respawned) worker ---"
req "GET nested arrays (32 keys)" -g "$U/dump_get.php?$(for i in $(seq 1 16); do printf 'a[]=%d&m[k%d][x]=%d&' $i $i $i; done)z=1"
req "POST urlencoded nested" --data 'a=1&b[]=2&b[]=3&c[x][y]=4' $U/dump_post.php
head -c 1048576 /dev/zero > /tmp/up.bin
req "multipart upload 1MiB" -F "up=@/tmp/up.bin" $U/upload.php
rm -f /tmp/jar
req "session request 1" -c /tmp/jar -b /tmp/jar $U/session.php
req "session request 2" -c /tmp/jar -b /tmp/jar $U/session.php

/usr/sbin/httpd -f $conf -k stop
for i in $(seq 1 50); do [ -f /tmp/httpd-$t.pid ] || break; sleep 0.2; done
echo "--- Apache error_log (startup/shutdown notices removed) ---"
grep -vE 'AH00558|AH00163|AH00094|AH00169|AH00489|AH00492|resuming normal|caught SIGTERM|Command line' $log | cut -c1-220
