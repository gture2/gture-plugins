# Documentation Update Output Style Guide

This file defines the formatting and tone conventions for documentation edits and for the summary comment produced by the `doc-writer` plugin.

---

## General Principles

- Be **faithful** — describe what the code now does, not what it used to do, and not what it might do in the future.
- Be **minimal** — the smallest edit that brings the doc into agreement with the code.
- Be **consistent** — mirror the repository's existing voice, heading style, table format, and code-block conventions.
- Be **specific** — name the symbol, command, route, env var, or file you are describing.
- Avoid filler phrases: "This is a great feature", "We have added the ability to…", "As you can see…".
- Never describe internal implementation in user-facing docs.

---

## Disposition Labels

Use these labels consistently in the summary comment:

| Label | When to use |
|---|---|
| `UPDATE` | An existing doc entry was edited to reflect a changed signature, default, behaviour, or example |
| `ADD` | A brand-new doc entry was created for a new public surface (symbol, command, env var, route, page) |
| `REMOVE` | A doc entry describing a now-removed public surface was deleted (or replaced with a deprecation note) |
| `RENAME` | References to a renamed symbol/command/env var/route/page were updated across the doc tree |
| `NO-OP` | A changed file was assessed and required no documentation work (internal change, refactor, test, formatting) |

---

## Editing Conventions per Documentation Surface

### README / top-level docs

- Update the **Quick Start**, **Usage**, **Features**, and **Configuration** sections when the PR changes how a user installs, runs, configures, or invokes the project.
- Update the **Compatibility / Requirements** section when the PR changes a supported version, prerequisite, or platform.
- Do **not** touch unrelated sections such as license, contributors, badges, or marketing copy.

### `docs/` tree (Markdown / MDX site)

- Follow the file naming and front-matter conventions already used (e.g. `slug`, `title`, `sidebar_position`).
- Preserve heading levels — if every page starts at `#` (one h1), keep that pattern.
- When adding a new page, insert a link to it from the most appropriate index / TOC file (if such a file exists).
- For MDX, never introduce JSX imports the rest of the site does not already use.

### API / reference docs

- For OpenAPI / Swagger: edit the YAML / JSON schema, not a generated artefact. Update `paths`, `components.schemas`, `description`, `required`, examples, and response shapes as needed. Bump `info.version` only if the repo's convention requires it.
- For Markdown API references: keep the existing column order in the parameter / response tables.
- When a symbol is removed, also remove its anchor from any "Reference" or "Index" pages that linked to it.

### Inline reference docs (JSDoc / TSDoc / docstrings / Rustdoc / GoDoc / XML doc comments)

- **Only adjust inline docs inside source files that the PR itself already touched.**
- Match the existing comment style (tags, capitalisation, period at end of summary, blank line before `@param`, etc.).
- Update `@param`, `@returns`, `@throws`, `@deprecated`, `@example`, `@since` as appropriate.
- Do not introduce a new doc-comment style if the repo does not already use it.

### CHANGELOG

- Use the repo's existing changelog format. If the file uses [Keep a Changelog](https://keepachangelog.com), place new entries under the `## [Unreleased]` heading in one of these sub-sections, in this order: **Added, Changed, Deprecated, Removed, Fixed, Security**.
- Write entries in past-tense, imperative-style summaries: "Added X", "Removed Y", "Fixed Z" — *not* "We have added", "This PR removes".
- Include the PR number in the entry where the repo's convention does so (e.g. `Added X (#42)`).
- Never invent a release version. Only edit `[Unreleased]` (or the equivalent section).

### ADRs / RFCs

- Do **not** add new ADRs — that requires human judgement on architectural intent.
- If an ADR is now superseded by the PR's changes and the repo has a "Superseded" status convention, update only the ADR's status field and add a single line referencing the PR. Do not rewrite the body.

### Plugin / package manifests (`description` fields)

- Update the `description` only when the PR changes the primary user-visible behaviour described by that field.
- Keep the description on a single line in the existing style.

---

## Code-Sample Maintenance

When a doc page contains an example that uses a symbol, command, route, or config key changed by the PR:

- If the symbol was renamed → update the example to the new name.
- If the signature changed → update the call site / payload in the example.
- If a parameter became required → add it to the example with a placeholder value.
- If a parameter was removed → remove it from the example.
- If the example was a runnable snippet (e.g. a fenced code block with a `bash` / `ts` / `py` tag), make sure it would still parse / type-check at a glance.

---

## Link and Cross-Reference Maintenance

When a doc file is renamed or removed:

- Sweep the doc tree with `Grep` for any relative link pointing at the old path and update or remove each one.
- Update anchors in any "Table of Contents" or "Index" pages.

Do not introduce new external links to third-party resources unless the existing docs already cite that resource.

---

## Tone for the Summary Comment

- Use **neutral, technical language** — this is automated output.
- State facts: "Updated `docs/api/users.md` to reflect the new `POST /users` payload."
- When a change requires human judgement and you skipped it, surface it in the **"Documentation gaps — please review"** section of the summary, with a specific question.
- Never apologise, hedge, or promise future updates.
- Commit message uses imperative mood: `docs: sync ...`, not `Documentation was synced ...`.

---

## What never to do

- Never delete a documentation file unless it describes a public surface that was removed by the PR.
- Never re-flow or re-format unchanged sections of a doc.
- Never translate documentation into a different language.
- Never copy text from external sources into the docs.
- Never add personal opinions, "TODO" notes, or speculative future work to the docs.
