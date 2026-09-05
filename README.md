# Agent Git Workflow

A portable agent skill for safe Git commits and remote merge workflows. It
provides two actions:

## Table of contents

- [Safety guarantees](#safety-guarantees)
- [Requirements](#requirements)
  - [Installing Gitleaks on Windows](#installing-gitleaks-on-windows)
- [Install the skill](#install-the-skill)
- [Usage](#usage)
- [Validation](#validation)
- [Other agents](#other-agents)
- [License](#license)

- `gitc` stages approved changes, scans them with Gitleaks, generates a concise
  commit message, and creates a local commit.
- `gitship` performs the same safety checks, pushes the current branch, creates
  a GitHub pull request or GitLab merge request, and merges it remotely when
  repository protections allow it. For .NET repositories it also audits direct
  and transitive NuGet dependencies for known vulnerabilities and deprecation
  before committing or pushing.

The workflow is designed for Codex but keeps the core instructions
agent-neutral so they can be adapted for other coding agents.

## Safety guarantees

Both actions:

- require a Git repository with a root-level `.gitignore`;
- read and follow repository-local agent instructions;
- pause on the remote default branch and require an explicit choice to
  continue on default, stop, or create/switch to a feature branch and resume;
- review the working tree and exclude unrelated changes;
- scan the exact staged contents with Gitleaks before committing;
- scan the committed branch range with Gitleaks before every push;
- redact detected secrets from command output;
- stop when required tools are unavailable or a scan fails;
- never add Gitleaks exceptions automatically; and
- never bypass branch protection, required reviews, or CI checks.

Before shipping a .NET repository, `gitship` always runs the dependency
precheck, including when the working tree is clean or the branch is already
pushed. It requires .NET SDK 8 or newer, explicitly enables NuGet audit in
`all` mode, and covers direct and transitive dependencies regardless of the
target framework's default. Vulnerability and deprecation reports are generated
and evaluated separately with JSON output version 1. An unsupported SDK or
incomplete audit blocks shipping.

Known vulnerabilities require an explicit choice to update the affected
packages, ignore named advisories for the current run only, or stop. Deprecated
packages without known vulnerabilities require an explicit choice to continue
with a recorded warning, update them, or stop. The workflow never updates
packages or writes permanent audit suppressions automatically. After an update,
it reruns restore, repository-required tests, and both dependency reports.
When `gitship` creates a commit after an advisory is accepted, the commit body
records the advisory, affected package and version, dependency type, and
one-run scope while leaving the conventional-commit subject focused on the
actual change. Existing commits are not rewritten solely to add this record;
the pull or merge request records it instead.

`gitship` detects GitHub or GitLab from the `origin` remote. Other providers
are rejected unless their workflow is added explicitly.

## Requirements

- Git
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [GitHub CLI](https://cli.github.com/) for GitHub remotes
- [GitLab CLI](https://gitlab.com/gitlab-org/cli) for GitLab remotes

### Installing Gitleaks on Windows

1. Download the appropriate Windows archive from the
   [official Gitleaks releases](https://github.com/gitleaks/gitleaks/releases).
2. Extract `gitleaks.exe` to a stable directory such as
   `C:\Tools\gitleaks`.
3. Add that directory to your user or system `PATH`.
4. Restart the terminal and the coding agent.
5. Verify the installation:

   ```powershell
   gitleaks version
   ```

The skill does not install Gitleaks automatically and does not continue when
Gitleaks is missing.

## Install the skill

Run the self-contained wrapper from the `skills-git-workflow` repository root:

```powershell
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1
```

It reads the skill name from `skills/git-workflow/SKILL.md`, resolves the
current user's home directory, and copies the complete skill to
`$HOME/.agents/skills/git-workflow`.

To synchronize an existing installation to the downloaded version and remove
files that no longer belong to the skill, run:

```powershell
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1 -RemoveExtraFiles
```

Without `-RemoveExtraFiles`, the wrapper overwrites current source files but
preserves any additional files already present in the installed skill folder.

The wrapper uses the bundled `tools/Copy-AgentSkillToUserProfile.ps1` utility.
Its reusable source is maintained in the `skills-utils` repository, but this
repository includes the version it needs and has no runtime dependency on
`skills-utils`.

## Usage

Invoke the skill explicitly:

```text
$git-workflow gitc
$git-workflow gitship
```

Natural-language requests containing `gitc` or `gitship` should also trigger
the skill.

`gitc` creates a local commit only. `gitship` may create a commit when needed,
push the current branch, open a pull or merge request against the remote
default branch, and request a normal remote merge.

When invoked from the remote default branch, the workflow now requires one of
three explicit options:

1. continue on the default branch (explicit confirmation required),
2. stop, or
3. create and switch to a non-default branch, then resume checks and continue.

## Validation

Run the dependency-free workflow contract test from the repository root:

```powershell
pwsh -NoProfile -File .\tests\Test-GitWorkflowSkill.ps1
```

The test verifies that committed and staged Gitleaks scanning, the mandatory
.NET precheck, SDK capability checks, stable JSON output, and synchronized
installation guidance remain present.

## Other agents

The `SKILL.md` workflow is intentionally written without Codex-specific shell
commands. Agents that support skill files can reuse it directly or through a
small product-specific adapter. Installation paths, metadata, permission
models, and invocation syntax may differ between products.

## License

MIT

## Versions and releases

This repository is versioned independently with stable SemVer tags
`vMAJOR.MINOR.PATCH`. All skills in the repository share that release. Skill
Markdown and PowerShell are distributed as validated source, without compilation.

Use a patch release for compatible corrections, a minor release for compatible
features, and a major release for breaking instructions, interfaces, or packaging.
The initial release is `v1.0.0`; do not edit a published tag to fix a release.

Merge a pull request after both `Validate (windows-latest)` and
`Validate (ubuntu-latest)` pass. Then run **Actions > Release > Run workflow**
on `main` with the new version. The workflow validates that exact commit again,
requires immutable releases, creates a new tag, prepares a draft, and publishes
it. A failed publication can leave a tag or draft for manual inspection; the
workflow never overwrites an existing tag. Publish a new version for corrections.

Repository rules require PRs, passing checks, an up-to-date branch, and resolved
review conversations on main. Force pushes and deletion are blocked. There are
no bypass actors and no required external approvals, permitting solo maintenance.
Version tags cannot be updated or deleted; releases are immutable after publication.

Use `$update-dknn-skills` from [skills-utils](https://github.com/dknn/skills-utils)
to install or update. New installations use Stable; Latest explicitly follows
the default branch. Installed source choices and pinned versions persist.
Commit SHAs and managed-file hashes identify installed content, not timestamps.
