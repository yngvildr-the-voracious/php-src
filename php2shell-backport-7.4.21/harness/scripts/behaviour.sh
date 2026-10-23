#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Request-level behaviour checks through php-cgi (no exploit, ordinary requests only).
# Usage: behaviour.sh <tree>      Prints one block per check: exit code, stdout, stderr.
set -uo pipefail
t=$1; cgi=/dak/work/$t/sapi/cgi/php-cgi; cli=/dak/work/$t/sapi/cli/php
www=/dak/www; tmp=$(mktemp -d)

# Run php-cgi as a web server would: CGI env vars, request body on stdin.
cgi_req() { # <script> <content-type> <body-file> [extra -d options...]
  local script=$1 ctype=$2 body=$3; shift 3
  env -i REDIRECT_STATUS=1 GATEWAY_INTERFACE=CGI/1.1 REQUEST_METHOD=POST \
      SCRIPT_FILENAME=$www/$script CONTENT_TYPE="$ctype" CONTENT_LENGTH=$(stat -c%s "$body") \
      $cgi -n -d display_errors=1 -d html_errors=0 "$@" < "$body" > $tmp/out 2> $tmp/err
  echo "exit=$?"
  echo "stdout: $(sed -e '/^X-Powered-By/d' -e '/^Content-type/d' $tmp/out | tr -s '\n' ' ' | cut -c1-300)"
  echo "stderr: $(tr -s '\n' ' ' < $tmp/err | cut -c1-300)"
}

# Multipart body with N text fields, plus optional extras appended by callers.
B=----dakboundary
multipart_fields() { for i in $(seq 1 $1); do printf -- '--%s\r\nContent-Disposition: form-data; name="f%d"\r\n\r\nv%d\r\n' $B $i $i; done; }

echo "### $t: $($cli -n -r 'echo PHP_VERSION;')"

echo; echo "--- T1 max_multipart_body_parts=3, 10 fields (new ini from the fix) ---"
{ multipart_fields 10; printf -- '--%s--\r\n' $B; } > $tmp/t1
cgi_req count_post.php "multipart/form-data; boundary=$B" $tmp/t1 -d max_multipart_body_parts=3

echo; echo "--- T2 duplicate Content-Disposition + 300 junk part headers ---"
{ printf -- '--%s\r\nContent-Disposition: form-data; name="first"\r\nContent-Disposition: form-data; name="second"\r\n' $B
  for i in $(seq 1 300); do printf 'X-Junk-%d: %0200d\r\n' $i 0; done
  printf '\r\nhello\r\n--%s--\r\n' $B; } > $tmp/t2
cgi_req dump_post.php "multipart/form-data; boundary=$B" $tmp/t2

echo; echo "--- T3 file upload, 1 MiB ---"
{ printf -- '--%s\r\nContent-Disposition: form-data; name="up"; filename="a.bin"\r\nContent-Type: application/octet-stream\r\n\r\n' $B
  head -c 1048576 /dev/zero; printf '\r\n--%s--\r\n' $B; } > $tmp/t3
cgi_req upload.php "multipart/form-data; boundary=$B" $tmp/t3

echo; echo "--- T5 memory_limit hit WHILE PARSING the request (before the script runs) ---"
{ printf 'a='; head -c 3145728 /dev/zero | tr '\0' 'x'; } > $tmp/t5
cgi_req ran.php application/x-www-form-urlencoded $tmp/t5 -d memory_limit=2M -d post_max_size=16M

echo; echo "--- T7 memory_limit hit INSIDE the script (ordinary app-level OOM) ---"
printf 'x=1' > $tmp/t7
cgi_req oom.php application/x-www-form-urlencoded $tmp/t7 -d memory_limit=8M

rm -rf $tmp
