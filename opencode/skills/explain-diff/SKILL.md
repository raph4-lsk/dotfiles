---
name: explain-diff
description: Explain what a pull request does, how it works, and what deserves attention in review. Takes a PR URL or number, or falls back to the current branch diff against its base.
argument-hint: [pr-url]
disable-model-invocation: true
---

# Explain Diff

Explain the pull request at `$ARGUMENTS`.

## 1. Resolve the target

`$ARGUMENTS` can be:

- A PR URL: `https://github.com/<owner>/<repo>/pull/<n>`
- A bare PR number
- Empty

If empty, explain the current branch using:

```bash
git diff $(git merge-base HEAD origin/main)...HEAD
```

State which range was used.

## 2. Handle the gh account

The active `gh` account may not have access to the target repository.

`arn_ibf` is an Enterprise Managed User and cannot read personal repositories.

`raph4-config` cannot read iBanFirst repositories.

If a `gh` command fails with an authorization error:

1. Run `gh auth status`.
2. Switch to the other account with `gh auth switch --user <account>`.
3. Retry the command.
4. Switch back to the account that was active before, even if the retry failed.

Never print or echo a token.

## 3. Gather the PR

Use:

```bash
gh pr view <target> --json title,body,author,baseRefName,headRefName,additions,deletions,files
gh pr diff <target>
```

Read the actual diff.

For a large diff:

- Focus on source changes.
- Skip lockfiles, generated code, and snapshots.
- State what was skipped.

A diff alone is not enough.

Also:

- Read changed files around the modified hunks.
- Find callers of changed functions or APIs.
- Check whether relevant tests cover the changed path.
- Look for behavior changes hidden by the diff.

## 4. Get the source

If the current directory is already a clone of the target repository, use it.

Otherwise:

```bash
WORK="${TMPDIR:-/tmp}/opencode-explain-diff"
rm -rf "$WORK" && mkdir -p "$WORK"
gh repo clone <owner>/<repo> "$WORK/repo" -- --depth=1 --quiet
git -C "$WORK/repo" fetch --depth=1 --quiet origin pull/<N>/head
git -C "$WORK/repo" checkout --quiet FETCH_HEAD
```

Read and grep inside `$WORK/repo`.

Never clone into the user's own directories.

Never remove any path other than `$WORK`.

## 5. Write the explanation

Write exactly three sections in English:

```markdown
## Summary

<what the PR changes, at the intent level, in 1 to 3 short lines>

## How

<the mechanism and main execution path>

## Review points

<important findings, most important first>
```

Keep sentences short and make the result easy to scan.

For review points, use numbered blocks:

```markdown
**1. 🔴 <short claim>**
<1 to 2 lines explaining where it is and why it matters.>
→ <action or open question when needed>
```

Severity markers:

- 🔴 correctness bug, security hole, data loss, race
- 🟠 behavior change, blast radius, breaking API or schema
- 🟡 missing coverage, hardcoded value, dependency, tradeoff
- 🟢 verified claim or risk ruled out

Skip emoji on short PRs where they add noise.

Review:

- Logic that can break.
- Existing callers affected by behavior changes.
- Missing test coverage.
- Security issues.
- Performance issues.
- Decisions worth a second opinion.

Do not review:

- Formatting.
- Naming taste.
- Generic advice.
- Things the linter already catches.

Separate verified facts from suspicions.

Do not walk through files one by one.

Do not simply restate the diff.

If there is nothing notable, write:

```text
Nothing notable.
```

Never use the em dash character.

## 6. Clean up

If a temporary clone was created, remove it immediately after the explanation:

```bash
rm -rf "${TMPDIR:-/tmp}/opencode-explain-diff"
```

Do this even if the analysis failed.
