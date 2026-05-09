# Setup Guide

The `web-app-tester` plugin has three prerequisites: Node.js, playwright-cli, and the GitHub CLI.

---

## Node.js 20+

Node.js is required for the Playwright Chromium browser install and as a fallback runtime for playwright-cli when its binary is not on PATH.

Verify:
```bash
node --version   # must be v20 or higher
```

Install from [nodejs.org](https://nodejs.org) if not present.

### Playwright Browser Caching

On the first test run the plugin installs Chromium (~150 MB) via npx. This takes ~30–60 seconds.

**Every subsequent run skips the install entirely** — the plugin checks for a cached browser before attempting any download.
---

## playwright-cli

playwright-cli drives all browser interactions — navigation, clicks, form fills, DOM evaluation, viewport resizing, and screenshots. After each command it returns a live YAML DOM snapshot that the orchestrator reads to verify the outcome and adapt the next action.

**Install globally (recommended):**

```bash
npm install -g @playwright/cli@latest
```

Verify:
```bash
playwright-cli --version
```

### How the plugin resolves playwright-cli at runtime

At the start of every run the plugin executes a single wrapper-creation block:

1. Checks if `playwright-cli` is on PATH
2. If not, runs `npm install -g @playwright/cli@latest`
3. Checks PATH again after install
4. If still not on PATH (common on Windows where global npm binaries may not be added to the active shell's PATH), resolves the JS entry point directly via `npm root -g` and wraps it in a `node` call

The result is a small shell script `_wat_pcli` written to the working directory. All browser commands in that run call `./_wat_pcli` — path resolution happens once, not per command. The wrapper is deleted automatically at the end of the run.

This means **playwright-cli does not need to be on PATH** — as long as Node.js and npm are available, the plugin will find and invoke it correctly.

---

## GitHub CLI

The plugin uses `gh` to read PR/issue content and post the results comment.

### Installation

| Platform | Command |
|---|---|
| macOS | `brew install gh` |
| Windows | `winget install GitHub.cli` |
| Linux (Debian/Ubuntu) | `apt install gh` |

### Authentication

```bash
gh auth login
```

Or set the environment variable:

```bash
export GITHUB_TOKEN=ghp_your_token_here
```

### Token Permissions

| Permission | Access | Why it's needed |
|---|---|---|
| **Metadata** | Read | Resolve repository owner and name |
| **Issues** | Read & Write | Fetch issue content and post result comments |
| **Pull requests** | Read & Write | Fetch PR content and post result comments |

---

## Troubleshooting

**`node: command not found`**
Install Node.js 20+ from [nodejs.org](https://nodejs.org) and ensure it is on your PATH.

**`gh: command not found`**
Install the `gh` CLI using the instructions above.

**`gh auth status` fails**
Run `gh auth login` or export `GITHUB_TOKEN` with a valid personal access token.

**`playwright-cli: command not found` during a run**
This is handled automatically — the plugin installs playwright-cli via `npm install -g` and resolves the path via `npm root -g` if the binary is not on PATH. No manual action needed. If the run still fails, verify that Node.js 20+ and npm are installed and working.

**`_wat_pcli` file left in project directory**
The plugin deletes this wrapper at the end of every run, including failed runs. If it persists, the run was interrupted before cleanup. Delete it manually: `rm _wat_pcli`.