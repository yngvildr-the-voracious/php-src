#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Trace what a mod_php worker writes right before it dies on memory_limit (patched build).
t=$1
yum -y -q install strace > /dev/null 2>&1 || { echo "strace install failed"; exit 1; }
/dak/scripts/apache-test.sh $t > /dev/null 2>&1   # writes /tmp/httpd-$t.conf
strace -f -tt -s 200 -e trace=write,writev,exit_group,exit -o /tmp/st.txt /usr/sbin/httpd -f /tmp/httpd-$t.conf -DFOREGROUND &
for i in $(seq 1 50); do curl -s -o /dev/null http://127.0.0.1:8080/pid.php && break; sleep 0.2; done
curl -s -o /dev/null http://127.0.0.1:8080/oom.php; echo "oom.php curl_exit=$?"
sleep 1; kill %1; sleep 1
echo "--- syscalls around the worker's exit ---"
grep -n -B4 'exit_group(1)\|_exit(1)\|exit(1)' /tmp/st.txt | grep -v 'resumed\|unfinished' | cut -c1-260 | tail -n 15
