[CmdletBinding()]
param(
    [string]$TargetRoot = (Join-Path $HOME ".agents"),

    [switch]$RemoveExtraFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$UtilityScript = Join-Path $PSScriptRoot "tools/Copy-AgentSkillToUserProfile.ps1"
$SkillRoot = Join-Path $PSScriptRoot "skills/git-workflow"

if (-not (Test-Path -LiteralPath $UtilityScript -PathType Leaf)) {
    throw "Bundled copy utility not found: $UtilityScript"
}

& $UtilityScript `
    -SourceRoot $SkillRoot `
    -TargetRoot $TargetRoot `
    -RemoveExtraFiles:$RemoveExtraFiles
