<#
JP ENGINE — Start-JPWork (one-button start workflow)
- Gates to repo root
- Syncs master (fetch/prune + pull --ff-only)
- Ensures clean tree (or optional -Stash)
- Creates feature branch
- Runs verify + doctor (if present)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$BranchName,

  [Parameter(Mandatory = $false)]
  [switch]$Stash,

  [Parameter(Mandatory = $false)]
  [switch]$SkipVerify,

  [Parameter(Mandatory = $false)]
  [switch]$SkipDoctor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) { throw $Message }

function Find-RepoRootFromScript {
  # script lives in <repo>\scripts\
  $root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
  return $root.Path
}

function Assert-JPRepoRoot([string]$Root) {
  $gitDir  = Join-Path $Root '.git'
  $marker  = Join-Path $Root 'docs\00_JP_INDEX.md'
  if (-not (Test-Path -LiteralPath $gitDir)) { Fail "JP guard: Not a git repo root: missing .git at '$Root'." }
  if (-not (Test-Path -LiteralPath $marker)) { Fail "JP guard: Not jp-engine: missing docs\00_JP_INDEX.md at '$Root'." }
}

function Exec([string]$File, [string[]]$Args) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $File
  $psi.Arguments = ($Args -join ' ')
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($out) { Write-Host $out.TrimEnd() }
  if ($p.ExitCode -ne 0) {
    if ($err) { Write-Host $err.TrimEnd() }
    Fail "Command failed ($File $($psi.Arguments)) exit code $($p.ExitCode)."
  }
}

function Git([string[]]$Args) { Exec -File 'git' -Args $Args }

function Get-GitOutput([string[]]$Args) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.Arguments = ($Args -join ' ')
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) {
    if ($err) { Write-Host $err.TrimEnd() }
    Fail "git $($psi.Arguments) failed with exit code $($p.ExitCode)."
  }
  return $out
}

function Ensure-CleanOrStash {
  $status = (Get-GitOutput @('status','--porcelain')).Trim()
  if ([string]::IsNullOrWhiteSpace($status)) { return }

  if (-not $Stash) {
    Write-Host $status
    Fail "JP guard: Working tree is not clean. Commit/stash manually, or re-run with -Stash."
  }

  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  Git @('stash','push','-u','-m',("JP Start-JPWork autosave " + $stamp))
  $status2 = (Get-GitOutput @('status','--porcelain')).Trim()
  if (-not [string]::IsNullOrWhiteSpace($status2)) {
    Write-Host $status2
    Fail "JP guard: Tried to stash but working tree still not clean."
  }
  Write-Host "Stashed local changes (including untracked)."
}

function Ensure-OnMasterAndSynced {
  $branch = (Get-GitOutput @('branch','--show-current')).Trim()
  if ($branch -ne 'master') {
    Git @('checkout','master')
  }

  Git @('fetch','--prune')
  Git @('pull','--ff-only')
}

function Resolve-BranchName {
  if (-not [string]::IsNullOrWhiteSpace($BranchName)) { return $BranchName.Trim() }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  return ("feat/" + $stamp)
}

function Assert-BranchDoesNotExist([string]$Name) {
  $local = (Get-GitOutput @('branch','--list',$Name)).Trim()
  if (-not [string]::IsNullOrWhiteSpace($local)) {
    Fail "JP guard: Branch already exists locally: '$Name'. Choose a different -BranchName."
  }

  $remotes = (Get-GitOutput @('remote')).Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
  if ($remotes -contains 'origin') {
    $remoteMatch = (Get-GitOutput @('ls-remote','--heads','origin',$Name)).Trim()
    if (-not [string]::IsNullOrWhiteSpace($remoteMatch)) {
      Fail "JP guard: Branch already exists on origin: '$Name'. Choose a different -BranchName."
    }
  }
}

function Run-IfExists([string]$PathFromRoot, [string]$Label) {
  $root = Find-RepoRootFromScript
  $full = Join-Path $root $PathFromRoot
  if (-not (Test-Path -LiteralPath $full)) {
    Write-Host ("Skipping {0} (missing: {1})" -f $Label, $PathFromRoot)
    return
  }

  Write-Host ("Running {0}: {1}" -f $Label, $PathFromRoot)
  Exec -File 'pwsh' -Args @('-NoProfile','-ExecutionPolicy','Bypass','-File', $full)
}

# ---- main ----
$repoRoot = Find-RepoRootFromScript
Assert-JPRepoRoot -Root $repoRoot
Set-Location -LiteralPath $repoRoot

Write-Host "JP Start-JPWork — repo root: $repoRoot"

# Tooling sanity: git must exist (use direct invocation; don't rely on wrapper here)
& git --version | Out-Host
if ($LASTEXITCODE -ne 0) { Fail "JP guard: git is required but failed to run." }

Ensure-CleanOrStash
Ensure-OnMasterAndSynced
Ensure-CleanOrStash

$targetBranch = Resolve-BranchName
Assert-BranchDoesNotExist -Name $targetBranch

Git @('checkout','-b',$targetBranch)
Write-Host "Created and switched to: $targetBranch"

if (-not $SkipVerify) { Run-IfExists -PathFromRoot 'scripts\jp-verify.ps1'  -Label 'verify' }
if (-not $SkipDoctor) { Run-IfExists -PathFromRoot 'scripts\jp-doctor.ps1'  -Label 'doctor' }

Write-Host ""
Write-Host "READY ✅"
Write-Host ("Branch: " + (Get-GitOutput @('branch','--show-current')).Trim())
Write-Host "Next: make your changes, commit, open PR (PR-only merges)."
