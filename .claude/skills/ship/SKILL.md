---
name: ship
description: Commit and push changes with a well-crafted commit message. Use this skill when the user says "ship", "commit", "push", "commit and push", or "ship it". Analyzes the diff, writes a conventional commit message, commits, and pushes.
---

Commit staged and unstaged changes with a clear, conventional commit message, then push to the remote.

## Workflow

### Step 1: Assess state

Run these in parallel:

1. `git status` (never use `-uall`) — see what's changed
2. `git diff` + `git diff --cached` — see all changes (staged and unstaged)
3. `git log --oneline -5` — see recent commit style
4. `git branch --show-current` — confirm current branch

If there are no changes (clean working tree, nothing staged), tell the user and stop.

### Step 2: Stage changes

Stage all relevant files by name. Be specific — avoid `git add -A` or `git add .`.

**Never stage:**
- `.env`, `.env.*` files
- Credential files, API keys, secrets
- `.DS_Store`, `node_modules/`, build artifacts
- Large binary files unless clearly intentional

If unsure about a file, ask before staging.

### Step 3: Analyze and compose commit message

Read the full diff of what's being committed. Compose a commit message following conventional commits:

**Format:**
```
<type>(<scope>): <summary>

<body — optional, only for non-obvious changes>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

**Types:**
- `feat` — new feature or capability
- `fix` — bug fix
- `refactor` — code restructuring, no behavior change
- `style` — formatting, CSS, design changes
- `chore` — build, config, dependencies, tooling
- `docs` — documentation only
- `test` — adding or updating tests

**Scope** (optional): the module or area affected — e.g., `api`, `auth`, `recipes`, `ui`, `shopping`, `mealplan`

**Rules for the summary line:**
- Lowercase, no period at end
- Imperative mood ("add feature" not "added feature")
- Under 72 characters
- Focus on *what* and *why*, not *how*
- Be specific: "add recipe search filtering" not "update recipes"

**Body rules:**
- Skip for obvious single-purpose changes
- Include for multi-file changes where the summary can't capture everything
- Explain *why* if the change isn't self-evident
- Keep it concise — 1-3 lines max

### Step 4: Commit

Always pass the message via heredoc for proper formatting:

```bash
git commit -m "$(cat <<'EOF'
type(scope): summary

Optional body.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

If a pre-commit hook fails: fix the issue, re-stage, and create a **new** commit (never amend).

### Step 5: Push

```bash
git push
```

If the branch has no upstream yet:

```bash
git push -u origin <branch-name>
```

If push is rejected (remote has new commits), fetch and merge first:

```bash
git fetch origin && git merge origin/<branch> --no-edit && git push
```

If there are merge conflicts, stop and tell the user.

### Step 6: Confirm

After pushing, run `git status` to verify clean state. Output the commit hash and a one-line summary of what was shipped.
