#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Does a mod_php worker's stderr (where the fix's _exit message goes) reach error_log?
t=$1; log=/dak/logs/apache-$t-error.log
/dak/scripts/apache-test.sh $t > /dev/null 2>&1   # (re)writes /tmp/httpd-$t.conf
: > $log
/usr/sbin/httpd -f /tmp/httpd-$t.conf -DFOREGROUND &
for i in $(seq 1 50); do curl -s -o /dev/null http://127.0.0.1:8080/pid.php && break; sleep 0.2; done
curl -s http://127.0.0.1:8080/stderr.php
curl -s -o /dev/null http://127.0.0.1:8080/oom.php; echo "oom.php curl_exit=$?"
sleep 1; kill %1; sleep 1
grep -E 'PROBE|Fatal|memory' $log || echo "(no PROBE/Fatal lines in error_log)"
