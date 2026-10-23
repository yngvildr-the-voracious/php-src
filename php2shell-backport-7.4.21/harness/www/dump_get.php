<?php echo "count=", count($_GET, COUNT_RECURSIVE), " a=", count($_GET['a'] ?? []), " m=", count($_GET['m'] ?? []), " ", md5(json_encode($_GET)), "\n";
// Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
