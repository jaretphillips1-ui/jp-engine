# JP Shell Template (uses repo helpers)
# Usage: pwsh -NoProfile -File .\scripts\jp-shell-template.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\jp-shell-helpers.ps1"

JP-Step "GATE" {
  JP-AssertCleanGit
  git status -sb | Write-Host
}

JP-Step "EXAMPLE: safe commit" {
  # Make a trivial change before you try this for real.
  # JP-GitCommitVerified -Message "Example: safe commit" -StageAll
  Write-Host "Template loaded OK."
}
