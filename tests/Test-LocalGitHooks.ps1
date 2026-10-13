#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$InstallerRelativePath = "skills/git-repository-settings/scripts/Install-LocalGitHooks.ps1"
$Installer = Join-Path $RepositoryRoot $InstallerRelativePath
$Pwsh = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$TempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$TestRoot = Join-Path $TempParent ("local-hooks-test-" + [guid]::NewGuid().ToString('N'))
$Utf8 = [System.Text.UTF8Encoding]::new($false)

function Invoke-TestGit {
    param([string]$Root, [string[]]$Arguments)
    $Output = @(& git -C $Root @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture Git command failed: $($Arguments -join ' ')"
    }
    return ($Output -join "`n").Trim()
}

function Assert-HookResult {
    param([string]$Label, [string]$Root, [string]$Hook, [bool]$Success, [string]$InputPath = '', [string]$ExpectedMessage = '')
    $Arguments = @('-C', $Root, 'hook', 'run')
    if ($InputPath) {
        $Arguments += "--to-stdin=$InputPath"
    }
    $Arguments += $Hook
    $Output = @(& git @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    if (($ExitCode -eq 0) -ne $Success) {
        throw "Unexpected hook result: $Label (exit $ExitCode). Output: $($Output -join ' ')"
    }
    if ($ExpectedMessage -and -not ($Output -join "`n").Contains($ExpectedMessage)) {
        throw "Expected guard did not run: $Label. Output: $($Output -join ' ')"
    }
    Write-Output "PASS: $Label"
}

function Assert-InstallerResult {
    param([string]$Label, [string]$Script, [string]$Root, [bool]$Success, [switch]$Check)
    $Arguments = @('-NoProfile', '-File', $Script, '-RepositoryRoot', $Root)
    if ($Check) {
        $Arguments += '-Check'
    }
    $Output = @(& $Pwsh @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE
    if (($ExitCode -eq 0) -ne $Success) {
        throw "Unexpected installer result: $Label (exit $ExitCode). Output: $($Output -join ' ')"
    }
    Write-Output "PASS: $Label"
}

try {
    $Seed = Join-Path $TestRoot 'seed'
    $Clone = Join-Path $TestRoot 'fresh clone'
    New-Item -ItemType Directory -Path $Seed -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'skills') -Destination $Seed -Recurse
    New-Item -ItemType Directory -Path (Join-Path $Seed 'tests') | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-GitRepositorySettingsSkill.ps1') -Destination (Join-Path $Seed 'tests')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-GitWorkflowSkill.ps1') -Destination (Join-Path $Seed 'tests')
    Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'README.md') -Destination $Seed
    $Rule = @'
title = "Synthetic fixture rule"
[[rules]]
id = "fixture"
description = "Non-secret test marker"
regex = '''LOCAL_TEST_SECRET_[A-Z0-9]{16}'''
'@
    [System.IO.File]::WriteAllText((Join-Path $Seed '.gitleaks.toml'), $Rule, $Utf8)
    Invoke-TestGit $Seed @('init', '--initial-branch=main') | Out-Null
    Invoke-TestGit $Seed @('config', 'user.name', 'Local hook test') | Out-Null
    Invoke-TestGit $Seed @('config', 'user.email', 'hook-test@example.invalid') | Out-Null
    Invoke-TestGit $Seed @('config', 'core.autocrlf', 'false') | Out-Null
    # Use an empty hook directory only for building the unguarded seed fixture.
    $SeedHooks = Join-Path $Seed '.git/hooks'
    Invoke-TestGit $Seed @('config', 'core.hooksPath', $SeedHooks) | Out-Null
    Invoke-TestGit $Seed @('add', '.') | Out-Null
    Invoke-TestGit $Seed @('commit', '-m', 'Local hook fixture') | Out-Null
    Invoke-TestGit $TestRoot @('clone', '--no-local', $Seed, $Clone) | Out-Null
    $CloneInstaller = Join-Path $Clone $InstallerRelativePath
    $HooksRoot = Join-Path $Clone '.git/hooks'
    $PreCommit = Join-Path $HooksRoot 'pre-commit'
    $PrePush = Join-Path $HooksRoot 'pre-push'

    Assert-InstallerResult 'fresh clone reports missing hooks without mutation' $CloneInstaller $Clone $false -Check
    if ((Test-Path -LiteralPath $PreCommit) -or (Test-Path -LiteralPath $PrePush)) {
        throw 'Check mode installed a hook.'
    }
    Assert-InstallerResult 'fresh clone installs from its versioned resources' $CloneInstaller $Clone $true
    $OriginalHash = (Get-FileHash -LiteralPath $PreCommit).Hash
    $OriginalWriteTime = (Get-Item -LiteralPath $PreCommit).LastWriteTimeUtc
    Assert-InstallerResult 'repeated installation is safe' $CloneInstaller $Clone $true
    if ((Get-Item -LiteralPath $PreCommit).LastWriteTimeUtc -ne $OriginalWriteTime) {
        throw 'Repeated installation rewrote an existing hook.'
    }
    Assert-InstallerResult 'check accepts installed hooks' $CloneInstaller $Clone $true -Check
    foreach ($Hook in @($PreCommit, $PrePush)) {
        $Bytes = [System.IO.File]::ReadAllBytes($Hook)
        if ($Bytes -contains 13 -or ($Bytes[0] -ne 35)) {
            throw 'Installed shell hook has CRLF or a BOM.'
        }
    }
    Assert-HookResult 'commits on main are blocked' $Clone 'pre-commit' $false -ExpectedMessage 'commits on main are blocked'
    Invoke-TestGit $Clone @('switch', '-c', 'work') | Out-Null
    $CleanPath = Join-Path $Clone 'clean.txt'
    [System.IO.File]::WriteAllText($CleanPath, "clean staged change`n", $Utf8)
    Invoke-TestGit $Clone @('add', 'clean.txt') | Out-Null
    $Marker = 'LOCAL_TEST_SECRET_' + '0123456789ABCDEF'
    [System.IO.File]::WriteAllText((Join-Path $Clone 'unstaged.txt'), $Marker, $Utf8)
    Assert-HookResult 'clean staged content passes and unstaged content is ignored' $Clone 'pre-commit' $true
    [System.IO.File]::WriteAllText($CleanPath, $Marker, $Utf8)
    Invoke-TestGit $Clone @('add', 'clean.txt') | Out-Null
    Assert-HookResult 'staged synthetic secret is blocked' $Clone 'pre-commit' $false

    $Baseline = Invoke-TestGit $Clone @('rev-parse', 'HEAD')
    $Tree = Invoke-TestGit $Clone @('write-tree')
    $SecretCommit = Invoke-TestGit $Clone @('-c', 'user.name=Local hook test', '-c', 'user.email=hook-test@example.invalid', 'commit-tree', $Tree, '-p', $Baseline, '-m', 'Synthetic secret fixture')
    $CleanTree = Invoke-TestGit $Clone @('rev-parse', "$Baseline`^{tree}")
    $CleanCommit = Invoke-TestGit $Clone @('-c', 'user.name=Local hook test', '-c', 'user.email=hook-test@example.invalid', 'commit-tree', $CleanTree, '-p', $Baseline, '-m', 'Clean fixture update')
    $Zero = '0' * $Baseline.Length
    $PushInput = Join-Path $Clone '.git/push-input'
    $Cases = @(
        @{ Label = 'push to main is blocked'; Local = $Baseline; Remote = $Zero; Ref = 'main'; Success = $false; Message = 'all pushes to main are blocked' },
        @{ Label = 'branch deletion is blocked'; Local = $Zero; Remote = $Baseline; Ref = 'work'; Success = $false; Message = 'ref deletion is blocked' },
        @{ Label = 'history rewriting is blocked'; Local = $Baseline; Remote = $SecretCommit; Ref = 'work'; Success = $false; Message = 'history rewriting is blocked' },
        @{ Label = 'unknown remote commit is blocked'; Local = $Baseline; Remote = ('f' * $Baseline.Length); Ref = 'work'; Success = $false; Message = 'Fetch before pushing' },
        @{ Label = 'secret in outgoing history is blocked'; Local = $SecretCommit; Remote = $Baseline; Ref = 'work'; Success = $false; Message = 'leaks found' },
        @{ Label = 'secret in new branch history is blocked'; Local = $SecretCommit; Remote = $Zero; Ref = 'work'; Success = $false; Message = 'leaks found' },
        @{ Label = 'clean fast-forward passes scan and contract test'; Local = $CleanCommit; Remote = $Baseline; Ref = 'work'; Success = $true; Message = '' },
        @{ Label = 'clean new branch passes scan and contract test'; Local = $Baseline; Remote = $Zero; Ref = 'work'; Success = $true; Message = '' }
    )
    foreach ($Case in $Cases) {
        $Record = "refs/heads/work $($Case.Local) refs/heads/$($Case.Ref) $($Case.Remote)`n"
        [System.IO.File]::WriteAllText($PushInput, $Record, $Utf8)
        Assert-HookResult $Case.Label $Clone 'pre-push' $Case.Success $PushInput $Case.Message
    }
    foreach ($SkillName in @('git-workflow', 'git-repository-settings')) {
        $FixtureSkillPath = Join-Path $Clone "skills/$SkillName/SKILL.md"
        $OriginalSkillText = [System.IO.File]::ReadAllText($FixtureSkillPath, $Utf8)
        [System.IO.File]::WriteAllText($FixtureSkillPath, 'broken fixture', $Utf8)
        Assert-HookResult "failing $SkillName contract test blocks push" $Clone 'pre-push' $false $PushInput
        [System.IO.File]::WriteAllText($FixtureSkillPath, $OriginalSkillText, $Utf8)
    }

    $Scanner = Invoke-TestGit $Clone @('config', '--local', '--get', 'localguard.gitleaksPath')
    Invoke-TestGit $Clone @('config', '--local', 'localguard.gitleaksPath', 'missing-local-hooks-test-scanner') | Out-Null
    Assert-HookResult 'missing scanner blocks commit' $Clone 'pre-commit' $false -ExpectedMessage 'gitleaks is required'
    Assert-HookResult 'missing scanner blocks push' $Clone 'pre-push' $false $PushInput 'gitleaks is required'
    Invoke-TestGit $Clone @('config', '--local', 'localguard.gitleaksPath', $Scanner) | Out-Null

    Remove-Item -LiteralPath $PrePush
    $CustomHook = "#!/bin/sh`nexit 0`n"
    [System.IO.File]::WriteAllText($PreCommit, $CustomHook, $Utf8)
    Assert-InstallerResult 'existing different hook stops all installation' $CloneInstaller $Clone $false
    if ((Test-Path -LiteralPath $PrePush) -or ([System.IO.File]::ReadAllText($PreCommit) -ne $CustomHook)) {
        throw 'Conflicting hooks were modified.'
    }
    Remove-Item -LiteralPath $PreCommit
    Assert-InstallerResult 'missing hooks can be restored' $CloneInstaller $Clone $true
    if ((Get-FileHash -LiteralPath $PreCommit).Hash -ne $OriginalHash) {
        throw 'Restored hook differs from the source.'
    }
    Invoke-TestGit $Clone @('config', 'core.hooksPath', 'custom-hooks') | Out-Null
    Assert-InstallerResult 'custom hooksPath is preserved' $CloneInstaller $Clone $false
    if ((Invoke-TestGit $Clone @('config', '--get', 'core.hooksPath')) -ne 'custom-hooks') {
        throw 'Custom hooksPath was changed.'
    }

    foreach ($ProfileName in @('codex-profile', 'claude-profile')) {
        $TargetRoot = Join-Path $TestRoot $ProfileName
        & (Join-Path $RepositoryRoot 'Copy-AgentsToUserProfile.ps1') -TargetRoot $TargetRoot
        foreach ($SkillName in @('git-workflow', 'git-repository-settings')) {
            $SourceSkillRoot = Join-Path $RepositoryRoot "skills/$SkillName"
            $InstalledSkillRoot = Join-Path $TargetRoot "skills/$SkillName"
            foreach ($SourceFile in Get-ChildItem -LiteralPath $SourceSkillRoot -Recurse -File) {
                $RelativePath = [System.IO.Path]::GetRelativePath($SourceSkillRoot, $SourceFile.FullName)
                $InstalledFile = Join-Path $InstalledSkillRoot $RelativePath
                if (-not (Test-Path -LiteralPath $InstalledFile -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $SourceFile.FullName).Hash -ne (Get-FileHash -LiteralPath $InstalledFile).Hash) {
                    throw "Skill installation did not preserve $SkillName/$RelativePath."
                }
            }
            $ExtraFile = Join-Path $InstalledSkillRoot 'extra.tmp'
            [System.IO.File]::WriteAllText($ExtraFile, 'obsolete fixture file', $Utf8)
        }
        & (Join-Path $RepositoryRoot 'Copy-AgentsToUserProfile.ps1') -TargetRoot $TargetRoot
        foreach ($SkillName in @('git-workflow', 'git-repository-settings')) {
            if (-not (Test-Path -LiteralPath (Join-Path $TargetRoot "skills/$SkillName/extra.tmp"))) {
                throw 'Normal installation removed an extra file.'
            }
        }
        & (Join-Path $RepositoryRoot 'Copy-AgentsToUserProfile.ps1') -TargetRoot $TargetRoot -RemoveExtraFiles
        foreach ($SkillName in @('git-workflow', 'git-repository-settings')) {
            if (Test-Path -LiteralPath (Join-Path $TargetRoot "skills/$SkillName/extra.tmp")) {
                throw 'Synchronized installation retained an extra file.'
            }
        }
        if (Test-Path -LiteralPath (Join-Path $TargetRoot 'CLAUDE.md')) {
            throw 'Skill installation created global instructions.'
        }
        Write-Output "PASS: both skills install and synchronize in $ProfileName"
    }
    $InstalledScript = Join-Path $TargetRoot 'skills/git-repository-settings/scripts/Install-LocalGitHooks.ps1'
    Invoke-TestGit $Clone @('config', '--unset', 'core.hooksPath') | Out-Null
    Assert-InstallerResult 'skill installed in an agent profile retains executable resources' $InstalledScript $Clone $true -Check
    Write-Output 'All local Git hook installation and behavior checks passed.'
}
finally {
    $ResolvedTestRoot = [System.IO.Path]::GetFullPath($TestRoot)
    $TempPrefix = $TempParent.TrimEnd([char[]]@('/', '\')) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $ResolvedTestRoot.StartsWith($TempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or (Split-Path $ResolvedTestRoot -Leaf) -notlike 'local-hooks-test-*') {
        throw 'Refusing cleanup outside the verified temporary test directory.'
    }
    if (Test-Path -LiteralPath $ResolvedTestRoot) {
        Remove-Item -LiteralPath $ResolvedTestRoot -Recurse -Force
    }
}
