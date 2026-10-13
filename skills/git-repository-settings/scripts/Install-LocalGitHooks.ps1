#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path,

    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ResolvedRepositoryRoot = & git -C $RepositoryRoot rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    throw "The target must be a Git working tree."
}
$ResolvedRepositoryRoot = [System.IO.Path]::GetFullPath($ResolvedRepositoryRoot)

$CustomHooksPath = & git -C $ResolvedRepositoryRoot config --get core.hooksPath
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
    throw "Could not inspect core.hooksPath."
}
if ($LASTEXITCODE -eq 0) {
    throw "Existing core.hooksPath requires review; it will not be changed."
}

$HooksPath = & git -C $ResolvedRepositoryRoot rev-parse --path-format=absolute --git-path hooks
if ($LASTEXITCODE -ne 0) {
    throw "Could not resolve the Git hooks directory."
}
$HooksPath = [System.IO.Path]::GetFullPath($HooksPath)
$RepositoryPrefix = $ResolvedRepositoryRoot.TrimEnd([char[]]@('/', '\')) + [System.IO.Path]::DirectorySeparatorChar
if (-not $HooksPath.StartsWith($RepositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "The hooks directory is outside this working tree; review the shared repository before installation."
}

# Refuse links rather than following them into a different installation.
$DirectoryToCheck = $HooksPath
while ($DirectoryToCheck -ne $ResolvedRepositoryRoot) {
    if (Test-Path -LiteralPath $DirectoryToCheck) {
        $DirectoryItem = Get-Item -LiteralPath $DirectoryToCheck -Force
        if ($DirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Linked Git directories require review before installation."
        }
    }
    $DirectoryToCheck = Split-Path $DirectoryToCheck -Parent
}

foreach ($TestName in @('Test-GitWorkflowSkill.ps1', 'Test-GitRepositorySettingsSkill.ps1')) {
    $VerificationScript = Join-Path $ResolvedRepositoryRoot "tests/$TestName"
    if (-not (Test-Path -LiteralPath $VerificationScript -PathType Leaf)) {
        throw "These hooks require this repository's skill contract test: $VerificationScript"
    }
}
$ScannerCommand = Get-Command gitleaks -CommandType Application -ErrorAction Stop | Select-Object -First 1
$ScannerPath = $ScannerCommand.Source.Replace('\', '/')
& $ScannerPath version
if ($LASTEXITCODE -ne 0) {
    throw "Gitleaks could not be executed."
}
$ScannerHelp = @(& $ScannerPath git --help) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "Gitleaks does not support the required Git scan mode."
}
foreach ($Option in @('--pre-commit', '--staged', '--log-opts', '--redact', '--timeout', '--no-banner')) {
    if (-not $ScannerHelp.Contains($Option)) {
        throw "Gitleaks does not support the required option: $Option"
    }
}

$SourceRoot = Join-Path (Split-Path $PSScriptRoot -Parent) "assets/hooks"
$Utf8 = [System.Text.UTF8Encoding]::new($false)
$HookFiles = [System.Collections.Generic.List[object]]::new()
foreach ($Name in @('pre-commit', 'pre-push')) {
    $SourcePath = Join-Path $SourceRoot $Name
    $Content = [System.IO.File]::ReadAllText($SourcePath, $Utf8).Replace("`r`n", "`n")
    if (-not $Content.StartsWith("#!/bin/sh`n") -or $Content.Contains("`r")) {
        throw "Invalid hook source: $SourcePath"
    }
    $ExpectedBytes = $Utf8.GetBytes($Content)
    $TargetPath = Join-Path $HooksPath $Name
    $Missing = -not (Test-Path -LiteralPath $TargetPath)
    if (-not $Missing) {
        $TargetItem = Get-Item -LiteralPath $TargetPath -Force
        if ($TargetItem.PSIsContainer -or ($TargetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw "Existing hook is not a regular file: $TargetPath"
        }
        $ExistingBytes = [System.IO.File]::ReadAllBytes($TargetPath)
        if ([Convert]::ToBase64String($ExistingBytes) -ne [Convert]::ToBase64String($ExpectedBytes)) {
            throw "Existing hook differs from the bundled source; it will not be overwritten: $TargetPath"
        }
        if (-not $IsWindows) {
            & /bin/test -x $TargetPath
            if ($LASTEXITCODE -ne 0) {
                throw "Existing hook is not executable: $TargetPath"
            }
        }
    }
    if ($Check -and $Missing) {
        throw "Missing hook: $TargetPath. Run this installer without -Check."
    }
    $HookFiles.Add([pscustomobject]@{ Path = $TargetPath; Bytes = $ExpectedBytes; Missing = $Missing })
}

$ConfiguredScanner = & git -C $ResolvedRepositoryRoot config --local --get localguard.gitleaksPath
if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
    throw "Could not inspect the local Gitleaks path."
}
if ($ConfiguredScanner -and $ConfiguredScanner -ne $ScannerPath) {
    throw "Existing localguard.gitleaksPath differs from the detected tool; review it before changing it."
}
if ($Check) {
    if (-not $ConfiguredScanner) {
        throw "Missing local Gitleaks configuration. Run this installer without -Check."
    }
    Write-Output "Local Git hooks and scanner configuration are current."
    return
}

# All conflicts are checked before creating any hook or changing configuration.
[System.IO.Directory]::CreateDirectory($HooksPath) | Out-Null
foreach ($HookFile in $HookFiles) {
    if ($HookFile.Missing) {
        $Stream = [System.IO.File]::Open($HookFile.Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
        try {
            $Stream.Write($HookFile.Bytes, 0, $HookFile.Bytes.Length)
        }
        finally {
            $Stream.Dispose()
        }
        if (-not $IsWindows) {
            & chmod u+x -- $HookFile.Path
            if ($LASTEXITCODE -ne 0) {
                throw "Could not mark the installed hook executable: $($HookFile.Path)"
            }
        }
        Write-Output "Installed hook: $($HookFile.Path)"
    }
}
if (-not $ConfiguredScanner) {
    & git -C $ResolvedRepositoryRoot config --local localguard.gitleaksPath $ScannerPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not configure the local Gitleaks path."
    }
}
Write-Output "Local Git hooks are installed. No remote settings were changed."
