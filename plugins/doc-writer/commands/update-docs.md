---
name: update-docs
description: Update the codebase documentation to match the changes introduced by a pull request. Analyses the PR's modified source files, locates the relevant docs (READMEs, /docs trees, inline reference docs, changelogs, OpenAPI specs, etc.), edits or creates the entries that need to be in sync with the new code, and opens a separate **companion documentation PR** whose target branch is the original PR's head — so the doc changes can be reviewed and merged into the feature branch independently. Works with GitHub, Azure DevOps, and any git repository.
argument-hint: [pr-number]
---

Update the documentation in the codebase to match the source changes in pull request $ARGUMENTS.

## What This Does

This command invokes the **orchestrator** agent which:

| Step | Action |
|------|--------|
| 1 | Detects the platform from `git remote get-url origin` |
| 2 | Resolves the PR number (from the argument or the current branch) |
| 3 | Checks whether the PR is open or already merged |
| 4 | Posts a "documentation update in progress" comment on the PR |
| 5 | Cuts a new `docs/pr-<n>-sync` branch off the PR's head (never commits to the PR branch directly) |
| 6 | Builds a codebase + documentation inventory (where docs live, what conventions are used) |
| 7 | Fetches the PR diff and classifies every changed file (source / test / config / doc / build) |
| 8 | Maps each source change to the documentation entries that describe it |
| 9 | Plans the doc edits: **update**, **add**, **remove**, **rename**, or **no-op** |
| 10 | Applies the doc changes — edits existing files, creates new ones, removes stale entries |
| 11 | Verifies cross-references, code samples, and links still resolve |
| 12 | Commits the doc-only changes on the docs branch and pushes it |
| 13 | Opens a **companion documentation PR** whose target is the original PR's head branch |
| 14 | Posts a structured documentation summary comment on the original PR, linking the new docs PR |

## Dispositions per documentation entry

| Disposition | Meaning |
|---|---|
| **Update** | Existing doc entry drifted from the new code — rewrite the affected section |
| **Add** | New public surface (API, command, config flag, page, etc.) — create a new doc entry |
| **Remove** | Entry describes a behaviour or symbol that no longer exists in the PR |
| **No-op** | The source change is internal (refactor, rename of private symbol, test, formatting) — no doc change required |

## How to Use

```
/update-docs              # Update docs for the open PR on the current branch
/update-docs 42           # Update docs for PR #42
```

## Trigger Prompt

The plugin is designed to be triggered automatically by an upstream automation with a prompt like:

> Pull request #{{pr-number}} in {{repository-name}} (branch: {{git-ref}}) has been tagged for documentation updates.
>
> Run `/update-docs {{pr-number}}` to analyze the modified source files and update the relevant documentation in the codebase.

## Scope — what counts as "documentation"

The orchestrator treats the following as documentation surfaces and keeps them in sync with code:

- `README.md`, `README.*` at any depth
- `docs/`, `doc/`, `documentation/`, `wiki/` directories
- `CHANGELOG.md`, `CHANGES.md`, `HISTORY.md`
- API reference files: `*.api.md`, `*-api.md`, OpenAPI / Swagger files (`openapi.yaml`, `swagger.json`)
- Inline reference docs in code comments (JSDoc/TSDoc, Python docstrings, GoDoc, Rustdoc, XML doc comments)
- `*.mdx` documentation site sources (Docusaurus, Nextra, Astro, VitePress, MkDocs)
- ADRs (`docs/adr/*.md`, `docs/decisions/*.md`)
- Configuration sample files referenced by docs (e.g. `.env.example`)
- Plugin / marketplace manifests when they expose a `description` that summarises behaviour (e.g. `.claude-plugin/marketplace.json`, `package.json`'s `description`)

## What it does NOT do

- Does **not** modify source files, tests, build configuration, or business logic
- Does **not** rewrite documentation for unchanged code, even if the existing docs look poor
- Does **not** generate new docs for purely internal changes (private refactors, dependency bumps, test-only PRs)
- Does **not** commit directly onto the original PR's branch — every doc change ships as a separate **companion documentation PR**, targeted at the original PR's head branch, so it can be reviewed independently

## Companion Docs PR Model

The plugin always works on its own branch (`docs/pr-<n>-sync`) and always delivers changes via a pull request:

| State of the original PR | Docs PR target branch |
|---|---|
| **Open** | The original PR's **head** branch (so merging the docs PR brings the docs into the feature branch before that PR lands) |
| **Already merged** | The original PR's **base** branch (the head branch may no longer exist) |

Re-running the plugin on the same PR re-uses the existing docs PR by pushing new commits onto `docs/pr-<n>-sync`.

## Platform Support

The plugin auto-detects the hosting platform from your git remote URL:

| Remote URL contains | Platform | How comments are posted |
|---|---|---|
| `github.com` | GitHub | GitHub CLI (`gh`) |
| `dev.azure.com` / `visualstudio.com` | Azure DevOps | REST API (`curl`) |
| Anything else | Generic | Report written to `doc-update-report.md` |

## Prerequisites

- Must be run inside a git repository with a remote configured
- **GitHub**: `gh` CLI installed and authenticated (`gh auth login`)
- **Azure DevOps**: `AZURE-DEVOPS-TOKEN` environment variable set
- **Pushing commits**: `GIT_TOKEN` (GitHub) or `AZURE-DEVOPS-TOKEN` (Azure DevOps)

---

Starting documentation update now...
