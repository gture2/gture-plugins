# Setup Guide

The `web-app-tester` plugin has three prerequisites: Node.js, playwright-cli, and a platform CLI or token depending on whether your repository is on GitHub or Azure DevOps.

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

### Chromium System Dependencies

Headless Chromium needs system shared libraries (`libnss3`, `libnspr4`, `libglib-2.0.so.0`, `libatk-1.0.so.0`, `libdbus-1.so.3`, and others). The plugin installs these automatically via `playwright install --with-deps chromium` when the runner has root/`sudo`.

**Sandboxed or rootless runners cannot install these at runtime.** `apt-get install` and `playwright install-deps` both require root and will fail. If you see the run report all steps as `BLOCKED` with a missing-shared-libraries message, bake the deps into the runner image instead:

```dockerfile
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN npm install -g @anthropic-ai/claude-code @playwright/cli playwright \
    && playwright install --with-deps chromium \
    && chmod -R a+rX /ms-playwright \
    && rm -rf /var/lib/apt/lists/* /root/.npm
```

Or base the image on Microsoft's prebuilt Playwright image, which ships Chromium + every system dep already:

```dockerfile
FROM mcr.microsoft.com/playwright:v1.49.0-jammy
```

The plugin runs a one-shot launch probe before iterating the test plan, so a misconfigured image fails fast with this exact guidance instead of timing out across every step.

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

Required when your repository is hosted on GitHub (`github.com` in the remote URL).

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

## Azure DevOps

Required when your repository is hosted on Azure DevOps (`dev.azure.com` or `visualstudio.com` in the remote URL).

The plugin uses `curl` with a Personal Access Token (PAT) to read PR/work item content and post result comments.

### Prerequisites

- `curl` must be available (`curl --version`)
- `python3` must be available — used for JSON serialisation in ADO API calls (`python3 --version`)

### Creating a Personal Access Token

1. In Azure DevOps, go to **User Settings → Personal access tokens**
2. Click **New Token**
3. Set the following scopes:

| Scope | Access | Why it's needed |
|---|---|---|
| **Work Items** | Read & Write | Fetch bug repro steps and acceptance criteria; post notification comments |
| **Code** | Read | Access PR metadata, threads, and linked items |
| **Pull Requests** | Read & Write | Fetch PR content and post test execution report |

4. Copy the token value — it is shown only once.

### Setting the Token

```bash
export AZURE-DEVOPS-TOKEN=your_pat_here
```

Add this to your shell profile (`.bashrc`, `.zshrc`, etc.) to persist it across sessions.

### Remote URL Formats

The plugin auto-detects the Azure DevOps organisation, project, and repository from the git remote URL. Both URL formats are supported:

| Format | Example |
|---|---|
| Modern | `https://dev.azure.com/{org}/{project}/_git/{repo}` |
| Legacy | `https://{org}.visualstudio.com/{project}/_git/{repo}` |

Verify your remote:
```bash
git remote get-url origin
```

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

**All steps `BLOCKED` with "missing system shared libraries" / `libnss3` / `libglib-2.0.so.0`**
The runner image is missing Chromium's native deps and lacks root to install them at runtime. See the **Chromium System Dependencies** section above — bake `playwright install --with-deps chromium` into the image, or switch to `mcr.microsoft.com/playwright:v1.49.0-jammy`.

**`AZURE-DEVOPS-TOKEN is not set`**
Export the token: `export AZURE-DEVOPS-TOKEN=your_pat_here`. Create a PAT in Azure DevOps with Work Items (Read+Write), Code (Read), and Pull Requests (Read+Write) scopes.

**`curl` returns 401 for Azure DevOps**
The PAT may have expired or have insufficient scopes. Re-generate the token in Azure DevOps and re-export `AZURE-DEVOPS-TOKEN`.

**`wi` entry returns "no linked PR found"**
The work item must have at least one pull request linked via the Azure DevOps PR → Work Items relationship. Link the PR from the PR creation page or the work item's "Links" tab, then re-trigger.
