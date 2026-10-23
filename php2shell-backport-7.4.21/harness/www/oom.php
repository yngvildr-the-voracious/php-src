<?php
register_shutdown_function(function () { echo "SHUTDOWN HANDLER RAN\n"; });
$s = str_repeat('x', 32 * 1024 * 1024);
echo "unreachable\n";
// Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
