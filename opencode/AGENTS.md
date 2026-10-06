# Global Instructions

## Scope

This is the personal OpenCode setup.

Use OpenCode for personal work. Claude Code remains the work-oriented setup.

Follow these instructions unless a more specific project instruction overrides them.

## Style

- Never use the em dash character (`—`).
- Use a colon, comma, parentheses, or rephrase instead.
- This applies everywhere: responses, code, comments, commit messages, PR descriptions, and documentation.

## Python

- Python docstrings must use exactly three lines:
  - opening `"""` alone
  - text on its own line without a trailing period
  - closing `"""` alone
- Do not add module-level docstrings.

Example:

```python
def build_session() -> requests.Session:
    """
    HTTP session with retries on transient errors
    """
```

## Code Changes

Before modifying code:

1. Explain what you plan to change.
2. Ask for confirmation.
3. Only then make the modification.

Reading, querying, searching, inspecting, and analyzing do not require confirmation.

Do not make speculative code changes without user approval.

## Git Safety

Never merge anything.

This includes:

- `git merge`
- `gh pr merge`
- GitHub merge APIs
- Any equivalent merge operation

Never push directly to:

- `main`
- `master`
- `integration`
- `develop`

Opening a pull request is allowed.

After opening a pull request, stop and let the user decide whether to merge it.

Never bypass these rules through another command or API.

## Commits

Commit messages must:

- Be in English
- Use lowercase imperative mood
- Be specific
- Be no longer than 60 characters for the subject
- Have no period at the end
- Avoid vague messages such as `update code` or `fix stuff`

Use the project's existing commit convention when one exists.

For this setup, the preferred gitmoji convention is:

- `fix` → `🐛 fix: <message>`
- `feat` → `✨ feat: <message>`
- `docs` → `📝 docs: <message>`
- `style` → `💄 style: <message>`
- `refactor` → `♻️ refactor: <message>`
- `test` → `✅ test: <message>`
- `chore` → `🚀 chore: <message>`
- `config` → `🔧 config: <message>`

## Pull Requests

PR descriptions must be:

- In English
- Short
- Precise
- Factual
- Written at the intent level

Do not:

- List modified files
- Walk through the diff file by file
- Add filler introductions
- Add AI-generated footers
- Use em dashes
- Add unnecessary background

Use the minimum number of sections needed for the change.

For normal feature and bug-fix PRs, prefer:

**Problem** (otherwise find something to match with use case or feature)

- What was broken or missing.

**Solution**

- What changed to address it.

Add testing or risk information only when it is genuinely useful.

## Reviews

When reviewing code:

- Read the actual diff.
- Inspect surrounding code when the diff alone is insufficient.
- Find callers when a function, API, or behavior changes.
- Check relevant tests.
- Separate verified facts from assumptions.
- Focus on correctness, security, behavior changes, missing coverage, and meaningful tradeoffs.
- Do not waste review space on formatting or naming preferences unless they affect correctness.

## Communication

Keep responses concise and practical.

Do not restate information that is already obvious from the command, diff, or file list.

When something cannot be verified, say so instead of guessing.
