---
name: test-strategy
description: Generate a risk-based test strategy and impact analysis. Accepts three entry points — a PR number, an Azure DevOps work item ID, or a GitHub issue number — then resolves all linked context and posts a business-readable Markdown report as a logical series of comments on the PR / issue / work item discussion. Usage: /test-strategy [pr|wi|issue] [id] [--no-perf] [--no-a11y]
argument-hint: [pr <n> | wi <id> | issue <n>] [--no-perf] [--no-a11y]
---

Generate a risk-based test strategy and impact analysis for $ARGUMENTS.

## You are the test strategy lead — run this yourself, do NOT delegate to an orchestrator sub-agent

**Critical execution rule (read first).** You, the top-level agent, perform every step below **directly, in the main context**. The specialist analyses (`requirement-collector`, `change-analyst`, `risk-assessor`, and then `test-guide-writer`) are run by spawning those sub-agents **from here**, using the `Task` / `Agent` tool.

Do **not** spawn a single `orchestrator` (or "test strategy") sub-agent and ask *it* to run the specialists. A sub-agent cannot spawn further sub-agents — in the Claude Agent SDK that fails with `No such tool available: Task. Task is not available inside subagents`, the specialist fan-out in **Step 6** silently degrades, and the comment series never gets posted. The parallel analysis only works when it is emitted from the top-level agent, which is you.

**This command is a procedure, not a description. Execute it now.** Running the command means *doing* every step below and posting the result — not summarising what the plugin "will" do. Producing a status message such as "the orchestrator is working on it" and then stopping is a **failure**. You are not done until the comment series has been posted (or, on the generic platform, written to the working directory).

Execute every step autonomously and in order. Do not ask for confirmation, clarification, or approval at any point. If a step fails, output a single error line describing what failed and stop — except where a step explicitly says "warn and continue".

---

## Input Parsing

The invocation takes the form:

```
/test-strategy [pr <n> | wi <id> | issue <n>] [--no-perf] [--no-a11y]
```

Parse `$ARGUMENTS`:

1. **Entry type** — the first non-flag token must be one of `pr`, `wi`, `issue`. If absent, default to `pr` and resolve the current branch's PR (`gh pr view --json number ...` on GitHub).
2. **ID** — the token following the entry type.
3. **Flags** — `--no-perf` skips performance test cases; `--no-a11y` skips accessibility test cases. Pass them through to `test-guide-writer`.

Store: `ENTRY_TYPE`, `ENTRY_ID`, `SKIP_PERF`, `SKIP_A11Y`.

---

## 1. Detect Platform (do this FIRST, before any other tool call)

```bash
git remote get-url origin
```

- Contains `github.com` → **GitHub** (use `gh` CLI)
- Contains `dev.azure.com` or `visualstudio.com` → **Azure DevOps** (use `curl` + `AZURE-DEVOPS-TOKEN`)
- Anything else → **Generic** (write locally, no posting)

Validate the entry type against the platform: `wi` requires Azure DevOps, `issue` requires GitHub, `pr` is valid on both. If incompatible, output one error line and stop.

## 2. Resolve the Entry Point and Discover Linked Context

Do a bidirectional lookup so the report has both the requirement side and the code-change side. Follow the platform-specific fetch recipes in the provider file:

- **GitHub** → `providers/github.md`
- **Azure DevOps** → `providers/azure-devops.md`

For `ENTRY_TYPE == pr`: fetch the PR (`gh pr view ${ENTRY_ID} --json number,title,body,state,headRefName,baseRefName,url,author,labels,files,additions,deletions,commits,closingIssuesReferences`) and discover the linked issue / work item. For `issue` / `wi`: fetch the item, then discover all linked PRs.

## 3. Post a "Test Strategy in Progress" Comment (within the first 3 tool calls)

Immediately after resolving the entry point, post a starting comment on the entry artefact so the author knows generation has begun. **Do not gather diffs, enrich docs, or launch sub-agents before this.**

- **GitHub** → `providers/github.md` — *Posting the "Test Strategy in Progress" comment*
- **Azure DevOps** → `providers/azure-devops.md` — *Posting the Starting Comment*
- **Generic** → skip (no API)

If posting fails, output a single warning line and continue — do not stop the run.

## 4. Gather Code Changes from Linked PRs

For every PR discovered in Step 2, collect the diff, changed files, and commit log. Detached CI worktrees often have **no** remote-tracking refs, so resolve the base with `git merge-base` and fall back to local branches:

```bash
HEAD_SHA=$(git rev-parse HEAD)
BASE_REF=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  || git for-each-ref --format='%(refname)' refs/remotes/origin | grep -v '/HEAD$' | head -1 \
  || git for-each-ref --format='%(refname)' refs/heads | head -1)
BASE_SHA=$(git merge-base "$BASE_REF" "$HEAD_SHA" 2>/dev/null || echo "$BASE_REF")
git diff --name-only ${BASE_SHA}...${HEAD_SHA} | tee /tmp/ts_changed_files.txt
git diff ${BASE_SHA}...${HEAD_SHA} > /tmp/ts_full_diff.patch
git log --oneline ${BASE_SHA}..${HEAD_SHA}
```

GitHub fallback when a PR is not local: `gh pr diff ${PR_NUMBER}` and `gh pr view ${PR_NUMBER} --json files,additions,deletions,commits`. Write large diffs to a file and pass sub-agents the **path**, not the contents.

## 5. Enrich with Repository Documentation & Synthesize Scope

`Glob`/`Grep` for PRDs, specs, ADRs, and test plans under `docs/`, `specs/`, `requirements/`, `design/`, `adr/`, `rfcs/`, `qa/` that relate to the changed-file paths and the item's domain terms. Then summarize, in your own context, before dispatching: what was requested (acceptance criteria / repro + root cause), what was built (across all PRs), child/discussion/doc context, change category, languages, critical surfaces (auth, payments, migrations, public APIs, PII), and scope. You pass this synthesis to each sub-agent — **they do not re-fetch.**

## 6. Run the Specialist Analysis (parallel sub-agent calls — MANDATORY, from here)

You are the top-level agent, so `Task` / `Agent` is available **here**. The tool is exposed as `Task` and/or `Agent` depending on the SDK version — use whichever your SDK accepts; if one returns `No such tool available`, retry the same call with the other name. If your SDK requires the plugin prefix, use `test-strategist:<name>`.

**Phase 1 — emit all three calls in the same assistant turn so they run in parallel.** Pass each the synthesis and the diff path (`/tmp/ts_full_diff.patch`), not raw re-fetch instructions:

| `subagent_type` | Focus |
|---|---|
| `requirement-collector` | Consolidate every testable requirement: acceptance criteria (PBI/Feature), repro steps + root cause (Bug), child items, comments, referenced docs |
| `change-analyst` | Map code changes to business-language behavioural impact; cross-reference each change against the requirements; produce a **Developer Changes Requiring Clarification** list |
| `risk-assessor` | Business-level risk summary — what could break, who is affected, how severe — plus regression surface and impacted-areas rating |

Wait for all three to return.

**Phase 2 — after Phase 1 completes**, spawn `test-guide-writer` with all three outputs plus the synthesis. It writes one Markdown file per planned comment, plus `index.json`, into:

```
${TMPDIR:-/tmp}/test-strategy-${ENTRY_TYPE}-${ENTRY_ID}/
```

It follows `styles/report-template.md` and `styles/strategy.md`, honours `--no-perf` / `--no-a11y`, and skips categories with no realistic surface. Capture this directory path.

### What NOT to do (anti-patterns)

- ❌ Spawning a single `orchestrator` / "test strategy" sub-agent and asking it to run the specialists. It cannot spawn sub-agents — the fan-out fails and nothing gets posted. Run the specialists from here.
- ❌ A long thinking turn followed by writing the comment files yourself. That is you *simulating* the specialists. Emit real `Task`/`Agent` calls.
- ❌ Sequential specialist calls in Phase 1 — they MUST be in one assistant turn so the runtime parallelizes them.
- ❌ Printing "the orchestrator is working on it" and stopping. Nothing runs in the background; if you didn't call the tools, the work didn't happen.

### Fallback if sub-agents are genuinely unavailable

If **both** `Task` and `Agent` return `No such tool available`, do the three analyses inline yourself from `/tmp/ts_full_diff.patch` and the synthesis, write the comment files in the same format, then **continue to Steps 7–8 exactly as normal**. A degraded path must still post the series.

## 7. Validate the Generated Comment Series

Before posting, sanity-check `test-guide-writer`'s output: `index.json` exists and lists every file with contiguous `k` (`1..N`); Comment 1 is the Overview with "Where Testers Should Focus First"; the final comment is the Coverage Map & QA Sign-off; every test case is in a `<details>` block; every "change requiring clarification" appears in `03-requirements-and-gaps.md`; each file is **under 50 KB** (`wc -c < <file>` < 51200). If a check fails, re-dispatch `test-guide-writer` — do not edit the files yourself.

## 8. Post the Comment Series

Follow the provider file for the detected platform — it owns URL capture, the two-pass Table-of-Contents back-fill, and label/tag application. Pass it the working directory from Step 6.

- **GitHub** → `providers/github.md` — post the series on the PR/issue, capture each URL, then PATCH Comment 1 to back-fill the TOC.
- **Azure DevOps** → `providers/azure-devops.md` — post on the work item discussion (or PR thread).
- **Generic** → `providers/generic.md` — no posting; the files in the working directory are the deliverable.

## 9. Final Output

After delivery, output a single confirmation line:

```
Test strategy posted for <entry-type> #<id>: <risk-level> — <N> test cases across <M> comments — first comment: <COMMENT_1_URL>
```

For the generic provider, replace the URL with the working directory path. If you reach this line without having posted (or written, on generic) the series, you have not completed the command — go back to Step 6.
