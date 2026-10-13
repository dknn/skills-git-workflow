# Git Workflow and Repository Settings

Two portable agent skills, installed together from this repository:

- `git-workflow`: safe local commits (`gitc`) and remote merge workflows (`gitship`).
- `git-repository-settings`: read-only governance audits (`audit`), secure
  repository setup (`init`), and explicitly requested local Git hooks.

The former `dknn/skills-git-repository-settings` repository is superseded by this
repository. Existing skill names and commands are preserved; the copy installer
now installs both skills. Installing the skills does not activate hooks or change
GitHub/GitLab settings.

## Table of contents

- [Installation til Codex og Claude Code (Windows)](#installation-til-codex-og-claude-code-windows)
- [Safety guarantees](#safety-guarantees)
- [Requirements](#requirements)
  - [Installing Gitleaks on Windows](#installing-gitleaks-on-windows)
- [Install the skill](#install-the-skill)
- [Repository settings and optional local hooks](#repository-settings-and-optional-local-hooks)
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

## Installation til Codex og Claude Code (Windows)

### Nødvendige værktøjer

- [Git](https://git-scm.com/downloads)
- [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows)
- [Gitleaks](https://github.com/gitleaks/gitleaks/releases): pak `gitleaks.exe`
  ud, og tilføj mappen til `PATH`.
- [GitHub CLI](https://cli.github.com/) til GitHub eller
  [GitLab CLI](https://gitlab.com/gitlab-org/cli) til GitLab.
- Til shipping af .NET-projekter: .NET SDK 8 eller nyere, kompatibelt med
  projektet.

### Installér begge skills

Åbn PowerShell i en mappe til kode:

```powershell
git clone https://github.com/dknn/skills-git-workflow.git
cd skills-git-workflow

# Codex
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1

# Claude Code
pwsh -NoProfile -File .\Copy-AgentsToUserProfile.ps1 -TargetRoot "$env:USERPROFILE\.claude"
```

Kør installationskommandoen for den agent, du bruger, eller begge.
Begge skills installeres under brugerprofilen i `.agents/skills` til Codex
og `.claude/skills` til Claude Code, hver i sin egen mappe.
Start derefter en ny session.

Kontrollér værktøjerne, og log ind på den relevante platform:

```powershell
git --version
pwsh --version
gitleaks version

# GitHub
gh auth login

# Eller GitLab
glab auth login
```

### Brug workflowet i agentens chat

| Handling | Codex | Claude Code |
| --- | --- | --- |
| Lokalt commit uden push | `$git-workflow gitc` | `/git-workflow gitc` |
| Commit efter behov, push og PR/MR med merge | `$git-workflow gitship` | `/git-workflow gitship` |
| Kontrollér repository-beskyttelse uden ændringer | `$git-repository-settings audit` | `/git-repository-settings audit` |
| Planlæg og opsæt repository-beskyttelse | `$git-repository-settings init` | `/git-repository-settings init` |

Workflowet scanner for secrets og respekterer repositoryets beskyttelse
og kontrolkrav. Projektet skal have en `.gitignore` i repositoryets rod.
`init` ændrer kun serverindstillinger efter godkendelse og med de nødvendige
rettigheder. Lokale hooks aktiveres separat; se afsnittet nedenfor.

### Fælles regel: Arbejd aldrig direkte på main/master

Tilføj dette til projektets `AGENTS.md`:

```markdown
## Git branches

Kontrollér den aktuelle Git-branch, før filer ændres.

Der må ikke udvikles eller committes direkte på main, master
eller repositoryets default branch. Vælg eller opret en separat
arbejdsbranch, før arbejdet fortsætter.

Ændringer skal merges via en pull request eller merge request.
Branch protection, krævede reviews og CI-kontroller må ikke omgås.
```

Opret også en `CLAUDE.md` ved siden af `AGENTS.md`, eller tilføj følgende
til den eksisterende fil:

```markdown
@AGENTS.md
```

Så indlæser Claude Code de fælles regler, også når det ikke læser
`AGENTS.md` direkte. Se [Claude Codes dokumentation om fælles instruktioner](https://code.claude.com/docs/en/memory#share-one-file-with-other-coding-tools).

Denne branchregel er en ekstra projektinstruktion, der gælder før redigering.
Skillen kontrollerer selv default branch ved `gitc` og `gitship` og følger
projektets strengere regler.

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
- PowerShell 7 for the bundled copy installer and optional local hooks
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

It reads each skill name from its `SKILL.md`, resolves the current user's home
directory, and copies both complete skills to `$HOME/.agents/skills/git-workflow`
and `$HOME/.agents/skills/git-repository-settings`. For Claude Code, use
`-TargetRoot "$env:USERPROFILE\.claude"` to install both under `.claude/skills`.

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

## Repository settings and optional local hooks

Use `git-repository-settings audit` to inspect default-branch protection,
direct/force-push restrictions, required PR/MR checks, blocking secrets scanning,
and runner availability. The audit is read-only. `init` prepares a plan and applies
approved settings only with the required GitHub/GitLab permissions. Missing
permissions or unavailable runners are reported as blockers.

The settings skill includes provider references, a small policy-profile example,
and local hook assets. Git does not copy active `.git/hooks` or local Git
configuration when cloning. To activate the bundled hooks **in this repository**,
with Git, Gitleaks, and PowerShell 7 available, run from its root:

```powershell
pwsh -NoProfile -File ./skills/git-repository-settings/scripts/Install-LocalGitHooks.ps1
pwsh -NoProfile -File ./skills/git-repository-settings/scripts/Install-LocalGitHooks.ps1 -Check
```

`-Check` verifies installation without changing it. The hooks block commits and
pushes to this repository's `main`, remote ref deletion, and history rewriting.
Gitleaks scans staged content before commit and outgoing history before push.
Both skill contract tests run before push. These hooks do not prevent editing
files; the `AGENTS.md`/`CLAUDE.md` branch rule above covers agent edits.

The installer preserves matching hooks and refuses conflicting hooks, custom
`core.hooksPath`, conflicting scanner paths, linked Git directories, or shared
hooks outside the checkout. It records the scanner path in repository-local Git
configuration; machine-specific paths are not committed.

Installed copies retain the script and assets. Pass `-RepositoryRoot <checkout>`
to target a checkout after reading its instructions. The hooks require the two
contract tests from this repository and protect `main`; review and adapt them
before use elsewhere, including repositories that use `master` or another default
branch. Local hooks are bypassable assistance and do not replace server-side
branch protection or required CI checks. Installing either skill does not install
global `AGENTS.md`/`CLAUDE.md` rules or activate hooks automatically.

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

Run all three checks from the repository root. The hook test requires Git,
Gitleaks, and PowerShell 7:

```powershell
pwsh -NoProfile -File .\tests\Test-GitWorkflowSkill.ps1
pwsh -NoProfile -File .\tests\Test-GitRepositorySettingsSkill.ps1
pwsh -NoProfile -File .\tests\Test-LocalGitHooks.ps1
```

The workflow contract test verifies that committed and staged Gitleaks scanning, the mandatory
.NET precheck, SDK capability checks, stable JSON output, and synchronized
installation guidance remain present.
The settings contract test checks the provider guidance and bundled resources.
The hook test uses isolated local repositories and fresh clones to verify hook
installation, blocking behavior, both installation targets, and synchronization.
It does not contact GitHub or push anything. CI runs all three on Windows and
Ubuntu with a pinned, checksum-verified Gitleaks release.

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
creates a new tag, prepares a draft, publishes it, and verifies the release
is immutable. Administrators enable immutability in repository settings; the
Actions token intentionally has no administration permission. A failed publication can leave a tag or draft for manual inspection; the
workflow never overwrites an existing tag. Publish a new version for corrections.

Repository rules require PRs, passing checks, an up-to-date branch, and resolved
review conversations on main. Force pushes and deletion are blocked. There are
no bypass actors and no required external approvals, permitting solo maintenance.
Version tags cannot be updated or deleted; releases are immutable after publication.

Use `$update-dknn-skills` from [skills-utils](https://github.com/dknn/skills-utils)
to install or update. New installations use Stable; Latest explicitly follows
the default branch. Installed source choices and pinned versions persist.
Commit SHAs and managed-file hashes identify installed content, not timestamps.
