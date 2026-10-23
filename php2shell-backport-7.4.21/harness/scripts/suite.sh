#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Run PHP's bundled test suite (~15.7k .phpt) for one tree with identical settings,
# so the per-build failure lists can be diffed.
# Usage: suite.sh <tree>
set -uo pipefail
t=$1; cd /dak/work/$t
export NO_INTERACTION=1 SKIP_ONLINE_TESTS=1 SKIP_SLOW_TESTS=1 REPORT_EXIT_STATUS=0
export TEST_PHP_EXECUTABLE=$PWD/sapi/cli/php TEST_PHP_CGI_EXECUTABLE=$PWD/sapi/cgi/php-cgi
$PWD/sapi/cli/php -n run-tests.php -n -q -j"${JOBS:-5}" --set-timeout 180 \
  -d extension_dir=$PWD/modules/ -d zend_extension=$PWD/modules/opcache.so -d opcache.enable_cli=0 \
  -w /dak/logs/suite-$t.failed \
  > /dak/logs/suite-$t.log 2>&1
sed -i "s|/dak/work/$t/||" /dak/logs/suite-$t.failed   # tree-relative paths for diffing
grep -A12 '^Number of tests' /dak/logs/suite-$t.log
