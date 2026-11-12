[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$SkillPath = Join-Path $RepositoryRoot "skills/git-workflow/SKILL.md"
$ReadmePath = Join-Path $RepositoryRoot "README.md"

function Assert-ContentMatch {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if (-not [regex]::IsMatch($Content, $Pattern)) {
        throw "Missing workflow contract: $Description"
    }
}

$SkillContent = Get-Content -LiteralPath $SkillPath -Raw
$ReadmeContent = Get-Content -LiteralPath $ReadmePath -Raw

Assert-ContentMatch `
    -Content $SkillContent `
    -Pattern '(?s)\A---\r?\nname: git-workflow\r?\ndescription: [^\r\n]+\r?\n---\r?\n' `
    -Description 'valid minimal skill frontmatter'

$SkillContracts = @(
    @{
        Pattern = 'betterleaks dir'
        Description = 'staged-content Betterleaks scanning'
    }
    @{
        Pattern = 'betterleaks git'
        Description = 'committed-content Betterleaks scanning'
    }
    @{
        Pattern = 'origin/<default>\.\.HEAD'
        Description = 'a bounded committed branch range'
    }
    @{
        Pattern = '(?s)Run the \.NET dependency precheck for every\s+`gitship` invocation'
        Description = 'a mandatory dependency precheck for every gitship path'
    }
    @{
        Pattern = 'Rerun it after any approved dependency update'
        Description = 'dependency revalidation after an approved package update'
    }
    @{
        Pattern = '(?s)mandatory even\s+when the working tree is clean or the\s+branch is already pushed'
        Description = 'clean-working-tree and already-pushed coverage'
    }
    @{
        Pattern = 'dotnet --version'
        Description = 'repository-selected SDK detection'
    }
    @{
        Pattern = '\.NET SDK 8 or newer'
        Description = 'the minimum NuGet audit SDK capability'
    }
    @{
        Pattern = '--output-version 1'
        Description = 'stable machine-readable NuGet report output'
    }
    @{
        Pattern = '(?s)Strip any `Co-authored-by` lines from generated, template, or\s+user-provided commit messages before creating the new commit\.\s+Never rewrite\s+existing commits'
        Description = 'stripping Co-authored-by trailers from new commits without rewriting existing commits'
    }
)

foreach ($Contract in $SkillContracts) {
    Assert-ContentMatch `
        -Content $SkillContent `
        -Pattern $Contract.Pattern `
        -Description $Contract.Description
}

Assert-ContentMatch `
    -Content $ReadmeContent `
    -Pattern '\-RemoveExtraFiles' `
    -Description 'synchronized skill installation guidance'

Write-Output "Git workflow skill contracts passed."
