#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# "No recompile" proof: build APCu ONCE against the UNPATCHED 7.4.21, then load that
# same apcu.so into each build and run APCu's own test suite.
set -uo pipefail
src=/dak/work/apcu; so=$src/modules/apcu.so
if [ ! -f $so ]; then
  cd $src && /dak/inst/7.4.21-orig/bin/phpize > /dak/logs/apcu-build.log 2>&1 \
    && ./configure --with-php-config=/dak/inst/7.4.21-orig/bin/php-config >> /dak/logs/apcu-build.log 2>&1 \
    && make -j8 >> /dak/logs/apcu-build.log 2>&1 || { echo "APCu build failed"; tail -n 20 /dak/logs/apcu-build.log; exit 1; }
fi
echo "apcu.so built against 7.4.21-orig: $(sha256sum $so | cut -c1-16)…"
for t in 7.4.21-orig 7.4.21-fix 7.4.33-fix; do
  php=/dak/work/$t/sapi/cli/php
  smoke=$($php -n -d extension=$so -d apc.enable_cli=1 -r 'apcu_store("k", ["a" => [1, 2]]); echo extension_loaded("apcu") ? "loaded v" . phpversion("apcu") . " fetch=" . json_encode(apcu_fetch("k")) : "NOT LOADED";' 2>&1)
  res=$(cd $src && TEST_PHP_EXECUTABLE=$php NO_INTERACTION=1 $php -n /dak/work/$t/run-tests.php -n -q \
          -d extension=$so -d apc.enable_cli=1 tests 2>&1 | grep -E '^Tests (passed|failed|skipped) ' | tr -s ' ' | tr '\n' ' ')
  echo "$t: $smoke | $res"
done
