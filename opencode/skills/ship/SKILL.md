---
name: ship
description: Commit, rename the branch, push, and open a pull request using the user's gitmoji convention. Always asks for confirmation before staging or committing.
disable-model-invocation: true
---

# Ship

Commit, push, and optionally open a pull request.

Never stage or commit before the user explicitly confirms the proposed plan.

## Convention

Commit format:

```text
fix      → 🐛 fix: <message>
feat     → ✨ feat: <message>
docs     → 📝 docs: <message>
style    → 💄 style: <message>
refactor → ♻️ refactor: <message>
test     → ✅ test: <message>
chore    → 🚀 chore: <message>
config   → 🔧 config: <message>
```

Branch naming:

```text
feat/<short-slug>
fix/<short-slug>
chore/<short-slug>
config/<short-slug>
docs/<short-slug>
refactor/<short-slug>
test/<short-slug>
style/<short-slug>
```

## 1. Assess the situation

Run:

```bash
git status
git diff --stat
git branch --show-current
git log --oneline -5
```

Inspect both staged and unstaged changes:

```bash
git diff
git diff --cached
```

Do not modify anything yet.

## 2. Determine the commit

Choose the most appropriate type:

- `feat`: new user-facing behavior
- `fix`: bug fix
- `refactor`: code restructure without behavior change
- `config`: configuration, tooling, CI/CD
- `chore`: maintenance, dependencies, generated files, cleanup
- `docs`: documentation only
- `test`: tests only
- `style`: formatting or whitespace only

Message rules:

- English
- Lowercase imperative mood
- Maximum 60 characters
- Specific
- No period
- No markdown
- No filler
- Pick the most significant change when several changes are present

## 3. Propose before changing anything

Before staging or committing, show:

```text
Type:    feat
Message: add user authentication with JWT
Branch:  feat/user-authentication
Commit:  ✨ feat: add user authentication with JWT

Files to stage:
  - src/auth/jwt.py
  - src/auth/middleware.py
  - tests/test_auth.py

PR description draft:
  ## Problem

  <problem>

  ## Solution

  <solution>
```

Ask the user to confirm.

The user may adjust:

- Type
- Commit message
- Branch name
- Files to stage
- PR description

Do not stage, commit, rename, or push before confirmation.

## 4. Rename the branch

If the current branch already matches the convention, keep it.

If the current branch is:

- `main`
- `master`
- `develop`

do not rename it and stop.

For an inconsistent feature branch:

```bash
git branch -m <new-branch-name>
```

Branch slugs must be:

- Lowercase
- Kebab-case
- 2 to 5 words
- Derived from the commit message
- Without issue numbers unless explicitly requested

## 5. Stage and commit

Stage only the files approved by the user.

Never blindly run:

```bash
git add .
```

Commit directly with the full message:

```bash
git commit -m "✨ feat: add user authentication with JWT"
```

Never use a shell alias instead of the explicit commit command.

## 6. Push

Check whether an upstream exists:

```bash
git rev-parse --abbrev-ref @{u} 2>/dev/null
```

If an upstream exists:

```bash
git push
```

Otherwise:

```bash
git push -u origin <branch-name>
```

Never push directly to:

- `main`
- `master`
- `integration`
- `develop`

Never force-push unless the user explicitly requests it.

## 7. Pull request

If the user requested a PR, or one already exists for the branch, create or update it with:

```bash
gh pr create
```

or:

```bash
gh pr edit
```

PR title must equal the commit message.

PR body:

- English
- Factual
- Concise
- Maximum 6 lines of text, excluding headings
- No file list
- No diff walkthrough
- No filler
- No AI footer
- No em dash

Preferred structure:

```markdown
## Problem

<what was broken or missing>

## Solution

<what changed>
```

For `feat` and `fix`, add:

```markdown
## How to test

<verification steps>
```

For `refactor`, add:

```markdown
## Risk

No behavior change. Covered by <tests or manual check>.
```

For `config`, add:

```markdown
## Risk

<required action: reinstall, new environment variable, or none>
```

For UI changes, add a `## Screenshot` section only when useful.

For a Jira or GitHub issue explicitly mentioned by the user, add:

```markdown
## Ticket

<link>
```

Never merge the PR.

After creating the PR, report its URL and stop.

## 8. Summary

After shipping:

```text
Shipped: ✨ feat: add user authentication with JWT → feat/user-authentication
```

If a PR was created, print its URL on the next line.
