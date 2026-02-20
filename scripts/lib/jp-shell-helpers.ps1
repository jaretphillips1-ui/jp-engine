Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function JP-Step {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][scriptblock]$Action
  )

  Write-Host ""
  Write-Host ("=== {0} ===" -f $Name) -ForegroundColor Cyan

  try {
    & $Action
    Write-Host ("PASS: {0}" -f $Name) -ForegroundColor Green
  } catch {
    Write-Host ("FAIL: {0}" -f $Name) -ForegroundColor Red
    throw
  }
}

function JP-AssertCleanGit {
  [CmdletBinding()]
  param([string]$Message = "Working tree must be clean.")

  $s = git status --porcelain
  if ($s) { throw ("{0}`n{1}" -f $Message, $s) }
}

function JP-GitCommitVerified {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Message,
    [switch]$StageAll
  )

  if ($StageAll) { git add -A | Out-Null }

  $before = (git rev-parse HEAD).Trim()

  # Commit. If hooks modify files, git commit will FAIL (non-zero) and we will throw.
  git commit -m $Message | Write-Host

  $after = (git rev-parse HEAD).Trim()
  if (-not $after -or $after -eq $before) {
    throw "Commit did not advance HEAD (likely hooks modified files and commit did not succeed)."
  }

  $lastMsg = (git log -1 --pretty=%B).Trim()
  if ($lastMsg -ne $Message) {
    throw ("Commit message mismatch. Expected:`n{0}`nActual:`n{1}" -f $Message, $lastMsg)
  }

  # Ensure clean after a successful commit
  JP-AssertCleanGit -Message "Commit succeeded but working tree is not clean (unexpected)."

  return $after
}

function JP-GitPushVerified {
  [CmdletBinding()]
  param([switch]$SetUpstream)

  if ($SetUpstream) {
    git push -u origin HEAD | Write-Host
  } else {
    git push | Write-Host
  }

  $aheadBehind = (git status -sb)
  if ($aheadBehind -match '\[ahead ') { throw "Push did not succeed (still ahead of origin)." }
}
