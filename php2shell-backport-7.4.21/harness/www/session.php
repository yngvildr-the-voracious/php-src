<?php session_start(); $_SESSION['n'] = ($_SESSION['n'] ?? 0) + 1; echo "session n=", $_SESSION['n'], "\n";
// Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
