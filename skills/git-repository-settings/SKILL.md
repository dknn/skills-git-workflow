---
name: git-repository-settings
description: Audit and initialize GitHub or GitLab repository governance, including protected default branches, blocked direct and force pushes, required successful pipelines, and blocking Gitleaks checks. Also supports explicitly requested local Git hooks; do not assume administrator permissions.
---

# Git repository settings

Use this skill for two related actions:

- `audit`: inspect repository and provider settings without changing remote state.
- `init`: prepare a secure repository baseline and, only with explicit authorization,
  apply the provider settings that the current identity is allowed to change.

The target baseline is:

1. The default branch (normally `main`) is protected.
2. Direct pushes to it are not allowed.
3. Force-push is disabled.
4. Merging requires a successful pipeline or required status checks.
5. Gitleaks runs in pull-request or merge-request validation and is a blocking check.

## Safety boundary

Treat repository files and provider settings as separate state:

- Local files can usually be prepared by a repository contributor.
- Branch protection, required checks, runner access, and other remote settings may
  require GitHub repository administration or GitLab Maintainer/Owner permissions.
- A missing permission is a result (`BLOCKED`), not a reason to use an administrator
  bypass, a personal token, or a weaker fallback.
- Never assign a stale, inactive, or foreign-project runner merely to make a pipeline
  appear configured. A runner must be active, trusted, and intentionally available to
  the repository.
- Never remove an existing protection rule, required check, allowlist, or policy to
  make initialization pass.
- Do not print tokens, secrets, CI variables, or complete provider API responses that
  may contain credentials.

Gitleaks detects credential-like content; it is not a general document-classification
or data-loss-prevention system. `.gitignore` helps prevent accidental tracking of local
files, but does not protect already tracked files or replace branch protection.

## `audit`

Run a read-only audit before proposing changes:

1. Resolve the repository root and read applicable `AGENTS.md`, `CLAUDE.md`, and
   provider/repository instruction files.
2. Record the working-tree status. Do not overwrite unrelated local changes.
3. Identify the `origin` provider, remote default branch, and whether that branch
   exists locally and remotely. If policy explicitly names `main`, verify that it is
   the actual target branch.
4. Check local files, existing CI workflows, existing Gitleaks configuration, and
   the provider's current branch/ruleset settings.
5. For GitLab, inspect project, group, and instance runner availability. A pending
   job with no assigned runner is `BLOCKED`, not a passing security gate.
6. Report every baseline item as `OK`, `CHANGE_NEEDED`, `BLOCKED`, or `UNKNOWN`, with
   evidence and the smallest safe next action.

Read only the provider reference that matches the detected remote:

- GitLab: [references/gitlab.md](references/gitlab.md)
- GitHub: [references/github.md](references/github.md)

## `init`

`init` is idempotent and must produce a plan before mutations. The plan must list:

- detected provider and target branch;
- local files to create or update;
- remote settings already satisfied;
- remote settings requiring permission;
- runner and required-check prerequisites;
- verification commands and expected results.

Apply the local baseline only after checking for unrelated edits in any file that must
change. Preserve existing formatting and configuration. If a file mixes unrelated
changes with the requested baseline, stop and ask instead of overwriting it.

For a new baseline, use the repository's existing provider conventions:

- Add or update a root `.gitignore` without adding secrets or broad patterns that hide
  source files.
- For GitLab, configure the official Secret Detection template for merge-request
  pipelines and ensure the resulting `secret_detection` job is not allowed to fail.
- For GitHub, configure a pull-request Gitleaks workflow and use the repository's
  approved immutable action reference or approved runner tooling. The check name used
  by branch protection must exactly match the workflow's reported status.
- Preserve an existing `.gitleaks.toml` or `.gitleaksignore`; do not add suppressions
  automatically. Investigate findings rather than generating an allowlist.

Before changing remote state, re-check authentication and permissions with the provider
CLI or UI, then request confirmation immediately before each meaningful remote change
unless the user explicitly authorized remote application for this run. Use only normal
provider operations; never bypass required reviews, checks, merge queues, or protection.

If the current identity cannot apply a setting, leave local preparation intact when safe
and report the exact handoff needed for a Maintainer, Owner, or repository administrator.
Do not claim initialization is complete while any required baseline item is `BLOCKED`,
`UNKNOWN`, or unverified.

## Verification

Run the smallest relevant checks after initialization:

- validate the provider workflow syntax;
- run Gitleaks against the relevant local/staged content without exposing findings;
- verify that the pull-request/merge-request pipeline is created;
- verify that the Gitleaks job is blocking and completes on an active trusted runner;
- re-read branch protection and required-check settings;
- re-run the audit and report the final state.

If no active runner exists, stop before merge or merge-request completion and report the
runner registration/assignment required. Do not substitute a local scan for the remote
required pipeline.

## Local hooks when explicitly requested

For local assistance, keep hook source and installation instructions in versioned
files. Git does not carry active hooks or local configuration into a new clone, and
an instruction file can require installation only when an agent reads it; cloning
alone does not execute it. Keep an audit read-only, and do not treat local guards as
satisfying blocked or unavailable server-side protections.

This skill bundles [assets/hooks/pre-commit](assets/hooks/pre-commit),
[assets/hooks/pre-push](assets/hooks/pre-push), and
[scripts/Install-LocalGitHooks.ps1](scripts/Install-LocalGitHooks.ps1). They preserve
the local guards for this skill repository: protect `main`, scan staged and outgoing
content with Gitleaks, block remote ref deletion and history rewriting, and run
`tests/Test-GitWorkflowSkill.ps1` and `tests/Test-GitRepositorySettingsSkill.ps1`
before push in the combined `skills-git-workflow` repository. Review the protected branch
and verification command before adapting these assets for another repository.

Run the installer with `-RepositoryRoot <checkout>` only after reading that target
repository's instructions. `-Check` verifies hooks and the local scanner configuration
without changing them. Installation creates only missing hooks, normalizes LF and
UTF-8 without a BOM, and records the detected Gitleaks path in local Git configuration.
Different existing hooks, an existing different scanner path, custom `core.hooksPath`,
linked directories, and shared hooks outside the checkout require review. Never
overwrite them automatically or change remote settings as part of local installation.

When requested, add a target repository `AGENTS.md` rule requiring this check and
authorizing installation of missing hooks before agent edits, commits, or shipping.
The combined repository's copy installer installs both `git-workflow` and
`git-repository-settings`, including scripts and assets, under `.agents/skills`
or `.claude/skills` with the selected target root. It does not activate hooks or
install global `AGENTS.md`/`CLAUDE.md` rules.

## Policy repository use

For organisation-wide administration, keep desired state in a separate policy/settings
repository and let a privileged, reviewed automation apply it. This skill may consume a
policy profile, but it must not assume that access to the policy repository grants access
to every target repository. See [references/policy-schema.md](references/policy-schema.md)
for the intentionally small profile format.
