#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Binary-compatibility checks between the unpatched 7.4.21 build and the patched builds.
set -uo pipefail
cd /dak
api() { /dak/inst/$1/bin/php -n -i | grep -E '^(PHP API|PHP Extension|Zend Extension|Zend Extension Build|PHP Extension Build) =>' | tr '\n' ' '; }
syms() { nm -D --defined-only /dak/work/$1/libs/libphp7.so | awk '{print $3}' | sort -u; }

echo "### 1. ABI identifiers (an extension refuses to load if these differ)"
for t in 7.4.21-orig 7.4.21-fix 7.4.33-fix; do echo "$t: $(api $t)"; done

echo; echo "### 2. Exported symbols of libphp7.so (mod_php): removed (<) / added (>)"
for t in 7.4.21-fix 7.4.33-fix; do
  echo "-- 7.4.21-orig -> $t: $(comm -23 <(syms 7.4.21-orig) <(syms $t) | wc -l) removed, $(comm -13 <(syms 7.4.21-orig) <(syms $t) | wc -l) added"
  comm -3 <(syms 7.4.21-orig) <(syms $t) | sed 's/^\t/  > /; s/^\([^ >]\)/  < \1/' | head -n 40
done

echo; echo "### 3. Installed headers that differ (what a PECL extension compiles against)"
diff -rq /dak/inst/7.4.21-orig/include /dak/inst/7.4.21-fix/include | sed 's|/dak/inst/7.4.21-orig/include/php/||; s| and .*||'
echo "-- struct/union/typedef lines touched in those headers:"
diff -r /dak/inst/7.4.21-orig/include /dak/inst/7.4.21-fix/include | grep -E '^[<>].*\b(struct|union|typedef)\b' || echo "  none"
