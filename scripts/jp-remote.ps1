[CmdletBinding()]
param(
  [string]$Url,
  [string]$Name = "origin",
  [string]$Branch = "master",
  [switch]$Push
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  (git rev-parse --show-toplevel) 2>$null
}

function Sanitize-RemoteUrl([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $null }
  $t = $s.Trim()

  # If someone pastes the prompt text + URL, extract only the URL portion.
  $idxHttps = $t.IndexOf("https://", [System.StringComparison]::OrdinalIgnoreCase)
  $idxGitAt = $t.IndexOf("git@", [System.StringComparison]::OrdinalIgnoreCase)

  if ($idxHttps -ge 0 -and ($idxGitAt -lt 0 -or $idxHttps -lt $idxGitAt)) {
    $t = $t.Substring($idxHttps).Trim()
  } elseif ($idxGitAt -ge 0) {
    $t = $t.Substring($idxGitAt).Trim()
  }

  # Drop any trailing junk after whitespace
  $t = ($t -split '\s+')[0].Trim()

  return $t
}

function Assert-ValidRemoteUrl([string]$u) {
  if ([string]::IsNullOrWhiteSpace($u)) { throw "No URL provided." }
  if ($u -notmatch '^(https://|git@)') {
    throw "Invalid remote URL: [$u]`nExpected URL starting with https:// or git@"
  }
}

$repo = Get-RepoRoot
if (-not $repo) { throw "Not inside a git repo." }

if ([string]::IsNullOrWhiteSpace($Url)) {
  $Url = Read-Host "Paste remote URL (HTTPS or SSH) then press Enter"
}

$Url = Sanitize-RemoteUrl $Url
Assert-ValidRemoteUrl $Url

# Determine if remote exists
$remotes = @(git remote)
$has = $remotes -contains $Name

if ($has) {
  git remote set-url $Name $Url
} else {
  git remote add $Name $Url
}

Write-Host ""
Write-Host "REMOTE SET:"
git remote -v

if ($Push) {
  Write-Host ""
  Write-Host "PUSHING: $Branch -> $Name/$Branch"
  git push -u $Name $Branch
}
