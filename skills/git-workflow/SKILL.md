---
name: git-workflow
description: Safely stage and commit Git changes or ship a branch through a GitHub pull request or GitLab merge request. Use when the user says gitc, asks for a local AI-generated commit, says gitship, or asks to push a branch and merge it remotely. Require a root .gitignore, repository-instruction compliance, staged-content Gitleaks scanning, focused diffs, and protected-branch safeguards.
---

# Git workflow

Perform one of two actions:

- `gitc`: create a safe local commit.
- `gitship`: create a safe commit if needed, push the branch, create a pull or
  merge request, and merge it remotely.

Treat a bare `gitc` or `gitship` request as explicit invocation. If the action
is unclear, ask which action the user wants.

## Common safety checks

Run these checks before either action:

1. Resolve the repository root with `git rev-parse --show-toplevel`. Stop when
   the current directory is not inside a Git repository.
2. Read applicable `AGENTS.md`, `CLAUDE.md`, and repository-specific agent
   instruction files before changing Git state. Follow stricter approval,
   testing, branch, and commit rules.
3. Require `<repository-root>/.gitignore` to be a regular file. Stop with:
   `Cannot continue: the repository root does not contain a .gitignore file.`
4. Inspect the working tree, current branch, remotes, and remote default branch.
   Prefer `refs/remotes/origin/HEAD`; query the provider only when it is absent.
5. When the current branch is the remote default branch, do not continue
    silently. Require one explicit user choice:
    - Option 1: continue on the default branch only with explicit confirmation
       that also satisfies repository rules.
    - Option 2: stop without changing Git state.
    - Option 3: create and switch to a new non-default branch, then resume the
       workflow from step 4 with fresh branch/remotes/status checks.
    If Option 3 is chosen and no branch name is provided, propose a concise,
    task-aligned branch name and ask for approval before creating it.
6. Review changes before staging. Include only changes belonging to the
   approved task. Stop when a file mixes related and unrelated edits or when
   task scope is uncertain.
7. Run repository-required checks before committing when practical. Report
   failures; never weaken or skip checks merely to complete the action.
8. Do not modify repository files, create branches, rewrite history, or install
   tools unless the selected action and repository rules authorize it.

### Default-branch Option 3 behavior

When the user selects Option 3:

1. Confirm the requested or proposed branch name is not the remote default
   branch name.
2. Verify whether the local branch already exists:
   - If it exists, switch to it.
   - If it does not exist, create it from the current commit and switch to it.
3. Re-run the branch safety context checks (current branch, remotes, remote
   default branch, and working-tree status).
4. Continue with normal change review, staging, scan, and action-specific steps.
5. Never delete, reset, or rewrite branches as part of this helper flow.

If Git reports dubious ownership, stop and explain the exact Git-recommended
remediation. Do not add a global `safe.directory` exception automatically.

## Stage and scan

1. Stage only the approved paths. Use `git add -A -- <paths>` so approved
   additions, modifications, and deletions are represented.
2. Review `git diff --cached --stat`, `git diff --cached --name-status`, and
   the staged patch. Stop if nothing is staged.
3. Confirm `gitleaks` is available by running `gitleaks version`.
4. If it is missing, stop and provide these instructions:
   - Download the correct archive from
     `https://github.com/gitleaks/gitleaks/releases`.
   - On Windows, extract `gitleaks.exe` to a stable directory such as
     `C:\Tools\gitleaks` and add that directory to `PATH`.
   - Restart the terminal and agent, then verify with `gitleaks version`.
   - Mention the official repository:
     `https://github.com/gitleaks/gitleaks`.
5. Create a uniquely named temporary directory outside the repository.
6. Export the complete staged blobs for paths reported by
   `git diff --cached --name-only --diff-filter=ACMR`, preserving safe relative
   paths. Read blobs from the index with `git show :<path>`; never copy working
   tree versions. Reject absolute paths or paths containing a `..` segment.
7. Run `gitleaks dir` against that staged snapshot with `--redact=100`,
   `--no-banner`, and a bounded timeout.
   - Pass the repository's `.gitleaks.toml` with `--config` when present.
   - Pass the repository's `.gitleaksignore` with
     `--gitleaks-ignore-path` when present.
   - Do not create or modify either file.
8. Remove only the verified temporary directory after scanning. On Windows,
   resolve its absolute path and confirm it is under the system temporary
   directory before recursive removal.
9. Stop on findings, timeout, execution error, unsupported version, or any
   incomplete scan. Do not print detected secret values and do not add
   allowlists automatically.

Do not commit unless the scan exits successfully.

## `gitc`

After the common checks and successful staged-content scan:

1. Read the staged diff and derive a concise conventional-commit message that
   describes only the staged change, such as `fix: preserve rollback state`.
2. Use a user-provided message only when it accurately describes the staged
   diff. Stop and ask when it is misleading.
3. Create one local commit. Do not push.
4. Report the commit hash, message, current branch, checks run, scan result,
   and remaining working-tree status. Identify unrelated unstaged changes.

## `gitship`

Complete `gitc` first when approved changes are not already committed. If the
working tree has no approved changes, ship the existing current-branch commits
after performing all applicable safety checks.

1. Require a configured `origin` remote and an upstream-ready non-default
   branch.
2. Detect the provider from the normalized `origin` URL:
   - GitHub: require authenticated `gh`.
   - GitLab: require authenticated `glab`.
   - Otherwise stop and report that the provider is unsupported.
3. If the provider CLI is missing, stop and link to its official installation
   page. Do not install it.
4. Fetch the remote and check for divergence or conflicts. Do not force-push,
   rewrite commits, or silently rebase.
5. Push the current branch normally, setting its upstream when needed.
6. Reuse an existing open pull or merge request for the same source and target
   branches; otherwise create one against the remote default branch. Generate
   an accurate title and body from the commits and verification results.
7. Request a normal remote merge using a merge method allowed by the
   repository. Never bypass required reviews, status checks, pipelines, merge
   queues, branch protection, or provider policy. Never approve the request on
   the user's behalf.
8. If the provider queues or blocks the merge, report the request URL and exact
   status; do not claim it merged.
9. After a confirmed merge, fetch `origin`, switch to the local default branch
   only when doing so cannot disturb local work, and update it using a
   fast-forward-only pull. Otherwise leave the current branch unchanged and
   explain why.
10. Report the commit hash, request URL, confirmed merge state, current branch,
    checks run, Gitleaks result, and working-tree status.

## Boundaries

- Never commit secrets, credentials, private keys, tokens, passwords, or
  sensitive local configuration.
- Never use `--no-verify`, `SKIP=gitleaks`, `--force`, administrator bypasses,
  or equivalent escape hatches.
- Never commit, push, merge, or alter remote state beyond the selected action.
- Treat Gitleaks as a detection gate, not proof that content is safe. Continue
  to inspect suspicious filenames and staged content.
