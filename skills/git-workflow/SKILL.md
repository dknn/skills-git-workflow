---
name: git-workflow
description: Safely stage and commit Git changes or ship a branch through a GitHub pull request or GitLab merge request. Use when the user says gitc, asks for a local AI-generated commit, says gitship, or asks to push a branch and merge it remotely. Require a root .gitignore, repository-instruction compliance, staged and committed-branch Gitleaks scanning, focused diffs, .NET dependency auditing before shipping, and protected-branch safeguards.
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

Run the common checks for every `gitship` invocation. When approved changes are
not already committed, perform the stage-and-scan steps before creating the
`gitc` commit. After the final approved commit exists, run the pre-push
committed-content scan below. Run the .NET dependency precheck for every
`gitship` invocation after the current approved dependency state is established
and before the first commit, push, pull-request, or merge-request mutation.
Rerun it after any approved dependency update, and carry a result forward only
while dependency inputs remain unchanged. The committed-content scan and
dependency precheck are mandatory even when the working tree is clean or the
branch is already pushed.

### Pre-push committed-content scan

1. Fetch `origin` without modifying the working tree, then resolve the current
   remote default branch and the exact committed range
   `origin/<default>..HEAD`. Stop when the range cannot be established, the
   fetch fails, or the branch contains no commits to ship.
2. Confirm `gitleaks` is available and supports the required `git` scan mode.
   Do not install or upgrade it automatically.
3. Run `gitleaks git` against only the resolved committed range with
   `--redact=100`, `--no-banner`, and a bounded timeout. Pass the range through
   `--log-opts` without interpolating untrusted shell text.
   - Pass the repository's `.gitleaks.toml` with `--config` when present.
   - Pass the repository's `.gitleaksignore` with
     `--gitleaks-ignore-path` when present.
   - Do not create or modify either file.
4. Stop before any push or request mutation on findings, timeout, execution
   error, unsupported version, or an incomplete scan. Do not print detected
   secret values or add allowlists automatically.

The staged-content scan protects a new commit from working-tree mistakes. The
committed-content scan independently protects every local branch commit that
would be shipped. Run both when `gitship` creates a commit.

### .NET dependency precheck

1. Detect supported .NET project and solution entry points, including `.sln`,
   `.slnx`, `.csproj`, `.fsproj`, and `.vbproj`, while excluding generated and
   vendor directories. Follow repository instructions when they designate the
   authoritative solution or project. Ensure every detected project is covered;
   stop and report an incomplete audit when coverage cannot be established.
2. If no supported .NET entry point exists, report the precheck as not
   applicable and continue. Otherwise require the `dotnet` CLI and run
   `dotnet --version` from the repository so any `global.json` selection is
   honored. Require .NET SDK 8 or newer because earlier SDKs do not provide the
   required NuGet audit capability. Confirm the selected SDK's package-list
   help supports `--include-transitive`, `--vulnerable`, `--deprecated`,
   `--format json`, and `--output-version 1`. Treat an unparseable SDK version
   or any missing capability as an incomplete audit and stop. Do not install an
   SDK, change `global.json`, or bypass a repository-pinned SDK.
3. Record the working-tree status before commands that may restore packages.
   Never stage restore-generated changes automatically. After the precheck,
   identify any new or modified files and require them to be reviewed as normal
   task changes or reverted by the user; do not discard them automatically.
4. Restore each selected entry point with NuGet auditing explicitly enabled and
   transitive auditing forced on, equivalent to:
   `dotnet restore <entry-point> -p:NuGetAudit=true -p:NuGetAuditMode=all`.
   Respect repository package sources, `NuGet.Config`, lock files, and source
   mappings. Do not add or replace an audit source. Treat an unavailable audit
   source, restore failure, timeout, or partial result as an incomplete security
   check and stop.
5. Produce separate machine-readable dependency reports for known
   vulnerabilities and deprecated packages. Use the SDK-compatible command
   form:
   - .NET 10 or newer: `dotnet package list --project <entry-point>`.
   - .NET 9 or older: `dotnet list <entry-point> package`.
   Add `--include-transitive --vulnerable --format json --output-version 1`
   for the vulnerability report and
   `--include-transitive --deprecated --format json --output-version 1` for the
   deprecation report. Run the reports separately because `--vulnerable` and
   `--deprecated` cannot be combined. Use temporary output outside the
   repository and remove only the verified temporary files afterward.
6. Parse the JSON reports rather than treating a zero exit status as proof that
   no packages were reported. For every finding, report the package ID,
   resolved version, affected project and target framework, whether it is direct
   or transitive, vulnerability severity and advisory URL when applicable, and
   available replacement or deprecation reason when supplied. Do not suppress
   findings because the affected code path appears unused.
7. For a transitive vulnerability, use `dotnet nuget why` when supported to
   identify the top-level dependency path. If that command is unavailable,
   retain the finding and explain that the dependency path could not be
   resolved; do not treat the audit as clean.
8. If vulnerabilities are found, stop and require one explicit user choice:
   - update or replace the affected package(s), then rerun restore,
     repository-required tests, both dependency reports, and the normal
     `gitship` checks;
   - ignore the listed advisory or advisories for this `gitship` run only and
     continue; or
   - stop without committing or changing remote state.
   Never update packages automatically. Never persist an ignore by modifying
   project files, `Directory.Build.props`, `NuGet.Config`, warning settings, or
   `NuGetAuditSuppress` unless the user separately requests that repository
   change. A one-run ignore must name the exact advisory or advisories in the
   commit body when `gitship` creates a commit, request body, and final report;
   broad or silent vulnerability suppression is not allowed.
9. If deprecated packages but no vulnerabilities are found, stop and require
   one explicit user choice:
   - continue with the deprecation warning recorded in the request body and
     final report;
   - update or replace the affected package(s), then rerun restore,
     repository-required tests, both dependency reports, and the normal
     `gitship` checks; or
   - stop without committing or changing remote state.
   Treat a package that is both deprecated and vulnerable under the stricter
   vulnerability flow.
10. If the reports are complete and contain no findings, record a successful
    .NET dependency precheck. Include its result, any explicitly ignored
    advisories, and any accepted deprecation warnings in the pull or merge
    request body and the final `gitship` report.

When `gitship` creates a commit after the user accepts a known vulnerability,
keep the conventional-commit subject focused on the actual code change. Add a
commit body containing one entry per accepted advisory with the advisory ID or
URL, package ID, resolved version, direct or transitive status, and the phrase
`accepted by user for this gitship run only`. Do not claim that the user
accepted any broader or permanent suppression. If all commits already exist,
do not amend or rewrite them solely to add this record; put the same details in
the pull or merge request body and final report instead.

After the committed-content scan and dependency precheck are clean or
explicitly resolved:

1. Require a configured `origin` remote and an upstream-ready non-default
   branch.
2. Detect the provider from the normalized `origin` URL:
   - GitHub: require authenticated `gh`.
   - GitLab: require authenticated `glab`.
   - Otherwise stop and report that the provider is unsupported.
3. If the provider CLI is missing, stop and link to its official installation
   page. Do not install it.
4. Reuse the fetch from the committed-content scan when it is still current;
   otherwise fetch again. Check for divergence or conflicts. Do not force-push,
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
    checks run, Gitleaks result, .NET dependency precheck result when
    applicable, and working-tree status.

## Boundaries

- Never commit secrets, credentials, private keys, tokens, passwords, or
  sensitive local configuration.
- Never use `--no-verify`, `SKIP=gitleaks`, `--force`, administrator bypasses,
  or equivalent escape hatches.
- Never commit, push, merge, or alter remote state beyond the selected action.
- Treat Gitleaks as a detection gate, not proof that content is safe. Continue
  to inspect suspicious filenames and staged content.
