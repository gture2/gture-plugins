#!/usr/bin/env bash
# validate-prerequisites.sh
# Validates that the environment is ready for web-app-tester operations.
# Run as a PreToolUse hook before Bash tool executions.

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "")

# Check Node.js is available (required for npx and Playwright browser install)
if ! command -v node > /dev/null 2>&1; then
    echo '{"decision": "block", "reason": "node is not installed or not in PATH. Node.js 20+ is required to run Playwright tests. Install Node.js from https://nodejs.org — see docs/setup.md"}'
    exit 0
fi

# Check playwright-cli is available (non-blocking if npx is present — orchestrator uses npx fallback)
if ! command -v playwright-cli > /dev/null 2>&1; then
    if ! command -v npx > /dev/null 2>&1; then
        echo '{"decision": "block", "reason": "playwright-cli is not installed and npx is not available. Install Node.js 20+ (which includes npx), or install playwright-cli globally: npm install -g @playwright/cli"}'
        exit 0
    fi
fi

# Only validate gh commands beyond this point
if ! echo "$COMMAND" | grep -qE "^gh "; then
    exit 0
fi

# Check gh CLI is installed
if ! command -v gh > /dev/null 2>&1; then
    echo '{"decision": "block", "reason": "GitHub CLI (gh) is not installed or not in PATH. Install it: brew install gh (macOS), winget install GitHub.cli (Windows), or apt install gh (Linux)."}'
    exit 0
fi

# Check gh is authenticated (or GITHUB_TOKEN is set)
if ! timeout 10s gh auth status > /dev/null 2>&1; then
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo '{"decision": "block", "reason": "gh CLI is not authenticated and GITHUB_TOKEN is not set. Run: gh auth login — or export GITHUB_TOKEN=ghp_xxx."}'
        exit 0
    fi
fi

# All checks passed — allow the command to proceed
exit 0
