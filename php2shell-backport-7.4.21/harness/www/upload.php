<?php $f = $_FILES['up'] ?? null;
echo $f ? "error={$f['error']} size={$f['size']} uploaded=" . var_export(is_uploaded_file($f['tmp_name']), true) : "no file", "\n";
// Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
