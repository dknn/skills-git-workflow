[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path $PSScriptRoot -Parent
$SkillRoot = Join-Path $RepositoryRoot "skills/git-repository-settings"
$SkillPath = Join-Path $SkillRoot "SKILL.md"
$MetadataPath = Join-Path $SkillRoot "agents/openai.yaml"

if (-not (Test-Path -LiteralPath $SkillPath -PathType Leaf)) {
    throw "Skill entrypoint not found: $SkillPath"
}

if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    throw "Skill UI metadata not found: $MetadataPath"
}

$SkillContent = Get-Content -LiteralPath $SkillPath -Raw

if ($SkillContent -notmatch '(?s)\A---\r?\nname: git-repository-settings\r?\ndescription: [^\r\n]+\r?\n---\r?\n') {
    throw "Skill frontmatter is invalid."
}

$RequiredTerms = @(
    'protected',
    'Direct pushes',
    'Force-push',
    'successful pipeline',
    'Gitleaks',
    'BLOCKED',
    'runner',
    'gitlab.md',
    'github.md',
    'policy-schema.md'
)

foreach ($Term in $RequiredTerms) {
    if ($SkillContent -notmatch [regex]::Escape($Term)) {
        throw "Missing skill contract: $Term"
    }
}

if ($SkillContent -match '\[TODO:|placeholder') {
    throw "Skill contains unfinished scaffold text."
}

$ReferencePaths = @(
    (Join-Path $SkillRoot "references/gitlab.md"),
    (Join-Path $SkillRoot "references/github.md"),
    (Join-Path $SkillRoot "references/policy-schema.md"),
    (Join-Path $SkillRoot "assets/hooks/pre-commit"),
    (Join-Path $SkillRoot "assets/hooks/pre-push"),
    (Join-Path $SkillRoot "scripts/Install-LocalGitHooks.ps1")
)

foreach ($ReferencePath in $ReferencePaths) {
    if (-not (Test-Path -LiteralPath $ReferencePath -PathType Leaf)) {
        throw "Referenced file not found: $ReferencePath"
    }
}

Write-Output "Git repository settings skill contracts passed."
