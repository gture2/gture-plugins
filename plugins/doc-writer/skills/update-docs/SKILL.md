---
name: update-docs
description: "Update the codebase documentation to match the changes introduced by a pull request. Analyses the PR diff, edits or creates the documentation entries that describe the changed surfaces, commits the doc-only edits on a separate docs branch, and opens a companion documentation PR targeting the original PR's head branch."
argument-hint: "[pr-number]"
disable-model-invocation: true
---

Update the documentation in the codebase to match the source changes in pull request $ARGUMENTS.

Use the **orchestrator** agent to run the full documentation-update flow. The orchestrator will:

1. Index the codebase structure
2. Detect the hosting platform from `git remote get-url origin`
3. Resolve the PR number (from argument or current branch)
4. Check whether the PR is open or already merged
5. Post a "documentation update in progress" comment on the original PR
6. Cut a new `docs/pr-<n>-sync` branch off the PR's head (never commits onto the PR's own branch)
7. Inventory the documentation surfaces (README, `docs/`, OpenAPI, CHANGELOG, ADRs, …) and the conventions they use
8. Fetch the PR diff and classify every changed file
9. Map each source change to the documentation entries that describe it today
10. Plan dispositions for each entry: **update**, **add**, **remove**, **rename**, or **no-op**
11. Apply the documentation edits — preserving the repo's existing style
12. Add a CHANGELOG entry under `[Unreleased]` for user-visible changes (when the repo uses a changelog)
13. Verify cross-references, code samples, and links still resolve
14. Commit the doc-only changes in a single commit on the docs branch and push the branch
15. Open a **companion documentation PR** whose target / base is the original PR's head branch (so it merges into the feature branch)
16. Post a structured documentation summary comment on the original PR, linking the new docs PR

If the original PR is already merged, the companion docs PR targets the original PR's base branch instead (since the head branch may no longer exist).

If no argument is given, update docs for the open PR on the **current branch**.

## Hard constraints

- **Source code is read-only.** Never edit `.ts`, `.js`, `.py`, `.go`, `.cs`, `.java`, `.rs`, `.cpp`, `.rb`, `.kt`, `.swift`, etc. The only exception is inline reference doc comments (JSDoc/TSDoc, docstrings, Rustdoc, GoDoc, XML doc comments) **inside source files that the PR itself already touched** — and only when those comments describe the symbol whose signature or behaviour changed.
- **Tests, lockfiles, build configuration, and dependency manifests are off limits.**
- **Every doc edit must trace back to a specific change in the PR diff.** Never reflow paragraphs, re-order sections, or "improve" documentation for unchanged code.
- **Match existing conventions** — heading levels, table style, code-block language tags, link style, CHANGELOG format.
