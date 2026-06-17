# Provider: GitHub

Use this provider when `git remote get-url origin` contains `github.com`.

## Prerequisites

The `gh` CLI must be installed and authenticated. Verify with:

```bash
gh auth status
```

If not authenticated, the user needs to run `gh auth login` or set the `GITHUB-TOKEN` environment variable.

---

## Fetching Issue Details

Fetch the full issue with metadata, labels, milestone, and comments:

```bash
gh issue view ${ISSUE_NUMBER} --json number,title,body,state,labels,assignees,milestone,comments,projectItems
```

Extract from the JSON response:
- `title` — issue title
- `body` — issue description
- `state` — OPEN / CLOSED
- `labels[].name` — existing labels
- `assignees[].login` — assigned users
- `milestone.title` — milestone name
- `comments[].body` — prior discussion and context

---

## Finding Related Issues

Find issues in the same milestone:

```bash
gh issue list --milestone "${MILESTONE}" --json number,title,state,labels --limit 20
```

Find issues with the same label:

```bash
gh issue list --label "${LABEL}" --json number,title,state --limit 20
```

Search by keyword from the issue body:

```bash
gh issue list --search "${KEYWORD}" --json number,title,state --limit 10
```

---

## Posting the "Elaboration in Progress" Comment

Post a single starting comment on the issue immediately after fetching it so the author knows the elaboration has started and that it can take a few minutes to complete.

```bash
gh issue comment ${ISSUE_NUMBER} --body "$(cat <<'EOF'
📋 **Requirement elaboration in progress**

I'm surrounding this item with the context a senior analyst would bring — intent, user journey, personas & adoption, domain & competitive insight, fit with existing requirements, and open questions. The elaboration will be posted as a series of comments when complete — this may take a few minutes.
EOF
)"
```

If posting fails, output a single warning line and continue — do not stop the elaboration.

---

## Posting a Comment

Post a comment on the issue:

```bash
gh issue comment ${ISSUE_NUMBER} --body "${COMMENT_BODY}"
```

For multi-line content, use a heredoc:

```bash
gh issue comment ${ISSUE_NUMBER} --body "$(cat <<'EOF'
## Heading

${CONTENT}
EOF
)"
```

---

## Applying the Readiness Signal

After posting all comments, apply the readiness label as a **triage hint**:

```bash
gh issue edit ${ISSUE_NUMBER} --add-label "${SIGNAL_LABEL}"
```

| Plugin signal | GitHub label |
|---|---|
| `GROOMED` | `groomed` |
| `NEEDS CLARIFICATION` | `needs-clarification` |
| `NEEDS DECOMPOSITION` | `needs-decomposition` |

---

## Posting Open Questions

Post each open question as a separate comment:

```bash
gh issue comment ${ISSUE_NUMBER} --body "${QUESTION_BODY}"
```

---

## Resolving the Issue

If no issue number was passed as an argument:

1. Parse the GitHub remote to get `{owner}` and `{repo}`:

```bash
git remote get-url origin
# e.g. https://github.com/org/repo.git  →  owner=org, repo=repo
```

2. List recent issues: `gh issue list --limit 10 --json number,title`

---

## Output

On completion:

```
Elaboration posted on issue #<number>: <signal> — <N> comments — <N> open questions
```
