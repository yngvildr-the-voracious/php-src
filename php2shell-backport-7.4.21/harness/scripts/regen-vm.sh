#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Regenerate the Zend VM with PHP's own generator (Zend/zend_vm_gen.php).
# The generator reads/writes next to itself (__DIR__), so it runs on a copy.
# Usage: regen-vm.sh <php-binary> <tree>   -> output in /dak/regen/<tree>/
set -euo pipefail
php=$1; tree=$2; out=/dak/regen/$tree
rm -rf "$out"; mkdir -p "$out"
cp /dak/work/$tree/Zend/{zend_vm_gen.php,zend_vm_def.h,zend_vm_execute.skl} "$out"/
[ -f /dak/work/$tree/Zend/zend_vm_order.txt ] && cp /dak/work/$tree/Zend/zend_vm_order.txt "$out"/
cd "$out" && "$php" zend_vm_gen.php
for f in zend_vm_execute.h zend_vm_opcodes.h zend_vm_opcodes.c zend_vm_handlers.h; do
  if cmp -s "$f" /dak/work/$tree/Zend/$f; then echo "$f: identical to tree"; else echo "$f: DIFFERS from tree"; fi
done
