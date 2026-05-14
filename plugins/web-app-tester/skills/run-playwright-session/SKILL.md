---
name: run-playwright-session
description: Phase 2 of web-app-tester. Resolves the playwright-cli wrapper, ensures a Chromium browser is cached, opens a single headless session, and executes the test plan adaptively — taking a DOM snapshot before every interaction, retrying failed steps up to 3 times, and capturing screenshots on the final retry. Honours PRODUCTION_WARNING by skipping data-modifying steps. Always cleans up temp files. Outputs an inline list of per-step results.
disable-model-invocation: true
---

# Phase 2 — Run Playwright Session

This skill is invoked by the **orchestrator** agent. It is not a standalone slash command.

## Inputs

| Variable | Source | Description |
|---|---|---|
| `TEST_URL` | gather-test-context | URL to test against |
| `PRODUCTION_WARNING` | gather-test-context | If `true`, skip any data-modifying step |
| `TEST_PLAN` | gather-test-context | Numbered/bulleted list of test steps |

## Outputs

A list of result entries (held inline, not written to a file):

```
{ n, desc, status: PASSED|FAILED|BLOCKED, reason, screenshot }
```

## Execution Rules (strictly enforced)

- Use `playwright-cli` for all browser testing — execute steps adaptively via the command loop, track results inline.
- Never launch multiple browser sessions for one test run — always use session `-s=wat`.
- Always delete temp files (`_wat_pcli`, `_wat_screenshot_*.png`) after the run, even if execution fails.
- Never install npm packages globally except `@playwright/cli` itself, which is required to run.

---

## Step 1: Prepare Playwright CLI and Chromium

**Resolve playwright-cli once and write a wrapper script `_wat_pcli`:**

Run this single block — it checks, installs if needed, and writes `_wat_pcli` regardless of whether the binary lands on PATH:

```bash
if command -v playwright-cli > /dev/null 2>&1; then
  printf '#!/bin/sh\nplaywright-cli "$@"\n' > _wat_pcli && chmod +x _wat_pcli && echo "CLI_READY (PATH)"
else
  npm install -g @playwright/cli@latest 2>&1
  if command -v playwright-cli > /dev/null 2>&1; then
    printf '#!/bin/sh\nplaywright-cli "$@"\n' > _wat_pcli && chmod +x _wat_pcli && echo "CLI_READY (installed)"
  else
    PCLI_JS="$(npm root -g)/@playwright/cli/playwright-cli.js"
    printf '#!/bin/sh\nnode "%s" "$@"\n' "$PCLI_JS" > _wat_pcli && chmod +x _wat_pcli && echo "CLI_READY (node path)"
  fi
fi
```

All three outcomes produce a working `_wat_pcli` wrapper. All browser commands in Step 2 use `./_wat_pcli` — the path is resolved once here and never re-evaluated per command.

**Critical:** the package is `@playwright/cli` (the playwright-cli tool), NOT `playwright` (the Node.js library). These are different packages with different behaviour. Never substitute one for the other.

**Check whether Playwright Chromium is already cached before attempting any install:**

```bash
node -e "const {chromium}=require('playwright');chromium.executablePath()" 2>/dev/null \
  && echo "BROWSER_READY" || echo "BROWSER_MISSING"
```

If output is `BROWSER_MISSING` → install the binary **and** its system shared libraries. Try `--with-deps` first (this is what gets `libnss3`, `libglib-2.0.so.0`, `libatk-1.0.so.0`, `libdbus-1.so.3`, etc. installed via `apt-get`). If that path is unavailable (no root / sandboxed runner), fall back to the binary-only install — system libs must already be baked into the environment in that case:

```bash
npx --yes playwright@1.49.0 install --with-deps chromium 2>&1 \
  || npx --yes playwright@1.49.0 install chromium 2>&1
```

**Preflight launch — catch missing system libraries before executing the test plan:**

A cached binary is not enough. Headless Chromium also needs `libnss3`, `libnspr4`, `libglib-2.0.so.0`, `libatk-1.0.so.0`, `libdbus-1.so.3`, and friends. Try a single launch+close cycle. If it fails, the test plan cannot run — **do not iterate the steps and accumulate 9× retry timeouts.**

```bash
LAUNCH_PROBE=$(node -e "const{chromium}=require('playwright');chromium.launch({headless:true}).then(b=>b.close()).then(()=>console.log('LAUNCH_OK')).catch(e=>{console.error('LAUNCH_FAIL: '+e.message);process.exit(1);})" 2>&1)
echo "$LAUNCH_PROBE"
```

If `LAUNCH_PROBE` contains `LAUNCH_OK` → continue to Step 2.

If `LAUNCH_PROBE` contains `LAUNCH_FAIL` and any of `libnss3`, `libglib`, `libatk`, `libdbus`, `shared libraries`, `Host system is missing dependencies`, `install-deps`, `playwright install` → **immediately** mark every step in `TEST_PLAN` as `🔴 BLOCKED` with reason:

```
Sandbox image missing Chromium system shared libraries (libnss3 / libglib / libatk / libdbus / etc.).
playwright install-deps requires root and is not available in this runner. Rebuild the runner image with the
system libraries baked in. Recommended Dockerfile additions:

  ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
  RUN npm install -g @anthropic-ai/claude-code @playwright/cli playwright \
      && playwright install --with-deps chromium \
      && chmod -R a+rX /ms-playwright \
      && rm -rf /var/lib/apt/lists/* /root/.npm

Or base the image on mcr.microsoft.com/playwright:v1.49.0-jammy which already includes Chromium + deps.
```

Then skip directly to Step 3 (cleanup) — do **not** attempt `open`, retries, or screenshots. The browser will not launch and every retry will fail identically.

---

## Step 2: Open Browser and Execute Steps Adaptively

**Navigate to the test URL:**

```bash
./_wat_pcli -s=wat open "${TEST_URL}"
```

Use `open` for initial navigation — not `goto`. `open` launches the browser session and loads the URL in one step. `goto` requires an existing open page and will fail with exit code 1 on session start.

**Take an initial snapshot to confirm the page loaded correctly:**

```bash
./_wat_pcli -s=wat snapshot
```

Read the YAML output. If the snapshot shows a login/auth page and the test plan does not include login steps, mark all steps `BLOCKED` with reason `Auth gate detected — no credentials provided` and skip to Step 3.

**For each step in TEST_PLAN, execute adaptively:**

1. **Map the action verb** to the appropriate command:
   - Navigate / Go to (mid-flow) → `./_wat_pcli -s=wat goto <url>`
   - Click / Tap → `./_wat_pcli -s=wat click <ref>`
   - Fill / Enter / Type → `./_wat_pcli -s=wat fill <ref> "<text>"`
   - Verify / Assert / Confirm / Expect / Check → `./_wat_pcli -s=wat snapshot` then inspect YAML for expected text or element

2. **Before every click or fill**, run `./_wat_pcli -s=wat snapshot` to get live element references from the current DOM. Use the `eN` references from the YAML output to target elements — do not guess CSS selectors.

3. **If `PRODUCTION_WARNING=true`:** skip any step that submits a form or performs a data-modifying action; mark those steps `BLOCKED` with reason `Skipped — production URL, read-only mode`.

4. **After each command**, run `./_wat_pcli -s=wat snapshot` to verify the outcome:
   - Expected text or element present → mark step `PASSED`
   - Unexpected blocker (modal, banner, overlay) detected → dismiss it with `./_wat_pcli -s=wat click <dismiss-ref>` and retry the step
   - Auth redirect detected → mark all remaining steps `BLOCKED` with reason `Auth gate detected mid-run`
   - Error state or element missing → retry

5. **Retry logic:** up to 3 retries with 2-second waits between attempts:
   ```bash
   sleep 2
   ```
   On the 3rd failure, capture a screenshot and mark the step `BLOCKED`:
   ```bash
   ./_wat_pcli -s=wat screenshot _wat_screenshot_N.png
   ```

6. **Track results inline** as you go (no JSON file). Build a result entry per step:
   ```
   { n, desc, status: PASSED|FAILED|BLOCKED, reason, screenshot }
   ```

Step statuses:
- `✅ PASSED` — step executed, expected outcome observed
- `❌ FAILED` — step executed, expected outcome NOT observed
- `🔴 BLOCKED` — step could not execute after 3 retries, auth gate detected, or skipped due to production URL

**Close the browser session after all steps complete:**

```bash
./_wat_pcli -s=wat close
```

Expected runtime: ~25–35 seconds for a 9-step plan on a cached browser.

---

## Step 3: Clean Up

Always run this, regardless of success or failure:

```bash
rm -f _wat_pcli _wat_screenshot_*.png
rm -rf .playwright-cli/
```

GitHub PR/issue comments do not support file attachments via `gh comment`, so the report describes screenshots inline as "captured at point of failure" rather than embedding them — see `providers/github.md`. Deleting the PNGs at the end of this phase is safe.

---

## Completion

When this skill finishes, hand off to `skills/post-test-report/SKILL.md` with the inline result list, `TEST_URL`, and `PRODUCTION_WARNING` in scope.
