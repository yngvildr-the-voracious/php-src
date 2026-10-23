#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Same as strace-oom.sh but with 'httpd -k start' (daemonized, like a real service start).
t=$1
yum -y -q install strace > /dev/null 2>&1 || { echo "strace install failed"; exit 1; }
/dak/scripts/apache-test.sh $t > /dev/null 2>&1
strace -f -tt -s 160 -e trace=write,writev,dup2,dup3,open,close,exit_group -o /tmp/st.txt /usr/sbin/httpd -f /tmp/httpd-$t.conf -k start &
for i in $(seq 1 50); do curl -s -o /dev/null http://127.0.0.1:8080/pid.php && break; sleep 0.2; done
curl -s -o /dev/null http://127.0.0.1:8080/oom.php; echo "oom.php curl_exit=$?"
sleep 1; /usr/sbin/httpd -f /tmp/httpd-$t.conf -k stop; sleep 1
echo "--- stderr (fd 2) setup in the parent ---"; grep -nE 'open\("/dev/null|dup2\([0-9]+, 2\)|dup3\([0-9]+, 2' /tmp/st.txt | cut -c1-160 | head
echo "--- worker's last syscalls ---"; grep -n -B3 'exit_group(1)' /tmp/st.txt | cut -c1-200
