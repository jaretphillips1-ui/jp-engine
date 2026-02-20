# JP Engine - One-button publish workflow
# Creates or updates a PR for the current work/* branch, watches checks, merges (squash + delete branch),
# syncs local master, then deletes the local feature branch.
#
# Examples:
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -DryRun
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -Live
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -Title "scripts: improve foo" -Live
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -NoWatch -Live
#   pwsh -NoProfile -File scripts/jp-publish-work.ps1 -TagGreenBaseline -Live
#
# DRYRUN behavior (preview mode):
# - Allowed on master (warns + exits after preview summary)
# - Allowed with dirty tree (warns + shows status)
# - Warns (does not throw) for:
#     - not work/*
#     - ahead=0 vs base
# - Will NOT attempt PR create/merge in DRYRUN unless it's a valid publishable scenario.
#
# LIVE behavior (strict mode):
# - Refuses on master
# - Refuses unless branch matches work/*
# - Refuses if working tree is dirty
# - Refuses if there are no commits vs base (prevents "No commits between..." PR loop)
# - Uses gh CLI only (no manual browser edits)

param(
  [switch]$ShowAuthStatus,

  [Parameter(Mandatory=$false)]
  [string]$Repo = 'jaretphillips1-ui/jp-engine', # or 'AUTO' to derive from origin

  [Parameter(Mandatory=$false)]
  [string]$RepoRoot = (Get-Location).Path,

  [Parameter(Mandatory=$false)]
  [string]$Base = 'master',

  [Parameter(Mandatory=$false)]
  [string]$Title,

  [Parameter(Mandatory=$false)]
  [string]$Body,

  [switch]$NoWatch,
  [switch]$TagGreenBaseline,

  [switch]$DryRun,
  [switch]$Live
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------- helpers ----------------
function Die([string]$m) { throw $m }

function Write-Section([string]$Text) {
  Write-Host ""
  Write-Host $Text -ForegroundColor Cyan
}

function Warn([string]$Text) {
  Write-Host $Text -ForegroundColor Yellow
}

function Info([string]$Text) {
  Write-Host $Text -ForegroundColor Cyan
}

function Require-Tool([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { Die "Missing tool: $name" }
}

function Assert-RepoRootLocal([string]$root) {
  if (-not $root) { Die "RepoRoot is empty." }
  if (-not (Test-Path -LiteralPath $root)) { Die "RepoRoot does not exist: $root" }
  Push-Location -LiteralPath $root
  try {
    if (-not (Test-Path -LiteralPath '.git')) { Die "Not a git repo root (.git missing): $root" }
  } finally {
    Pop-Location
  }
}

function Get-RepoSlugFromOrigin() {
  $u = (git remote get-url origin 2>$null)
  if (-not $u) { Die 'Cannot read origin remote URL.' }
  $u = $u.Trim()

  if ($u -match '^https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?$') { return ("{0}/{1}" -f $Matches[1], $Matches[2]) }
  if ($u -match '^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$')       { return ("{0}/{1}" -f $Matches[1], $Matches[2]) }

  Die ("Unrecognized origin URL format: {0}" -f $u)
}

function Get-CurrentBranch() {
  $b = (git branch --show-current).Trim()
  if (-not $b) { Die "Could not determine current branch." }
  return $b
}

function Get-DirtyStatusLines() {
  return @(git status --porcelain)
}

function Get-CommitCountVsBase([string]$BaseBranch, [string]$Branch) {
  $cnt = (git rev-list --count ("origin/{0}..{1}" -f $BaseBranch, $Branch)).Trim()
  if (-not $cnt) { return 0 }
  return [int]$cnt
}

function Ensure-RemoteUpdated() {
  git fetch origin --prune | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "git fetch failed." }
}

function Ensure-GhAuth([switch]$Preview) {
  if ($Preview) {
    Write-Section "== DRYRUN: gh auth status (informational) =="
    try { & gh auth status 2>&1 | Out-Host } catch { Warn "DRYRUN: gh auth status failed (ok for preview)." }
    return
  }

  Write-Section "== gh auth status =="
  & gh auth status 2>&1 | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "gh auth status failed. Authenticate gh before running -Live." }
}

function Find-OpenPR([string]$RepoFull, [string]$HeadBranch, [string]$BaseBranch) {
  try {
    $j = & gh pr view --repo $RepoFull --head $HeadBranch --json number,url,title,state 2>$null
    if ($LASTEXITCODE -eq 0 -and $j) {
      $p = (($j -join "`n") | ConvertFrom-Json)
      if ($p -and ($p.state -eq 'OPEN') -and $p.number) { return $p }
    }
  } catch { }

  try {
    $existing = @(& gh pr list --repo $RepoFull --head $HeadBranch --base $BaseBranch --state open --json number,url,title | ConvertFrom-Json)
    if ($existing -and $existing.Count -gt 0) { return $existing[0] }
  } catch { }

  return $null
}

function Get-OrCreatePR([string]$RepoFull, [string]$HeadBranch, [string]$BaseBranch, [string]$MaybeTitle, [string]$MaybeBody, [switch]$Preview) {
  $pr = Find-OpenPR -RepoFull $RepoFull -HeadBranch $HeadBranch -BaseBranch $BaseBranch
  if ($pr) {
    Write-Host ("PR: #{0} {1}" -f $pr.number, $pr.url) -ForegroundColor Green
    return [int]$pr.number
  }

  # Guard: must have commits (prevents GraphQL "No commits between..." loop)
  $ahead = Get-CommitCountVsBase -BaseBranch $BaseBranch -Branch $HeadBranch
  if ($ahead -lt 1) {
    if ($Preview) {
      Warn ("DRYRUN: would refuse PR create: No commits between {0} and {1} (ahead={2})." -f $BaseBranch, $HeadBranch, $ahead)
      return 0
    }
    Die ("Refusing PR create: No commits between {0} and {1} (ahead={2})." -f $BaseBranch, $HeadBranch, $ahead)
  }

  $t = $MaybeTitle
  if (-not $t) { $t = (git log -1 --pretty=%s).Trim() }
  if (-not $t) { $t = "work: $HeadBranch" }

  $b = $MaybeBody
  if (-not $b) {
    $b = @"
Automated via jp-publish-work.ps1

- Branch: $HeadBranch
- Base:   $BaseBranch
- Mode:   $(if ($Preview) { 'DRYRUN' } else { 'LIVE' })
"@
  }

  if ($Preview) {
    Write-Section "== DRYRUN: would create PR =="
    Info ("gh pr create --repo {0} --base {1} --head {2} --title <...> --body <...>" -f $RepoFull, $BaseBranch, $HeadBranch)
    return 0
  }

  Write-Section "== Create PR =="
  $createdUrl = & gh pr create --repo $RepoFull --base $BaseBranch --head $HeadBranch --title $t --body $b
  if ($LASTEXITCODE -ne 0) { Die "gh pr create failed." }
  if (-not $createdUrl) { Die "gh pr create returned empty output." }

  $m = [regex]::Match($createdUrl, '/pull/(\d+)$')
  if (-not $m.Success) { Die "Could not parse PR number from: $createdUrl" }

  $prNum = [int]$m.Groups[1].Value
  Write-Host ("Created PR: #{0} {1}" -f $prNum, $createdUrl) -ForegroundColor Green
  return $prNum
}

function UpdatePRText([string]$RepoFull, [int]$PrNum, [string]$MaybeTitle, [string]$MaybeBody, [switch]$Preview) {
  # Deterministic: always gh pr edit (no manual browser typing)
  $t = $MaybeTitle
  if (-not $t) { $t = (git log -1 --pretty=%s).Trim() }
  if (-not $t) { $t = "Publish work branch" }

  $b = $MaybeBody
  if (-not $b) {
    $b = @"
Automated via jp-publish-work.ps1
- Squash merge
- Delete branch after merge
"@
  }

  if ($Preview) {
    Write-Section "== DRYRUN: would update PR title/body =="
    Info ("gh pr edit {0} --repo {1} --title <...> --body <...>" -f $PrNum, $RepoFull)
    return
  }

  Write-Section "== PR Edit (title/body) =="
  & gh pr edit $PrNum --repo $RepoFull --title $t --body $b | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "gh pr edit failed." }
}

function WatchChecks([string]$RepoFull, [int]$PrNum, [switch]$SkipWatch, [switch]$Preview) {
  Write-Section "== PR Checks =="
  if ($Preview) {
    Info ("gh pr checks {0} --repo {1}{2}" -f $PrNum, $RepoFull, ($(if ($SkipWatch) { '' } else { ' --watch' })))
    return
  }

  if ($SkipWatch) { & gh pr checks $PrNum --repo $RepoFull | Out-Host }
  else { & gh pr checks $PrNum --repo $RepoFull --watch | Out-Host }

  if ($LASTEXITCODE -ne 0) { Die "PR checks failed." }
}

function MergePR([string]$RepoFull, [int]$PrNum, [switch]$Preview) {
  Write-Section "== Merge PR =="
  if ($Preview) {
    Info ("gh pr merge {0} --repo {1} --squash --delete-branch" -f $PrNum, $RepoFull)
    return
  }
  & gh pr merge $PrNum --repo $RepoFull --squash --delete-branch | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "gh pr merge failed." }
}

function SyncBase([string]$BaseBranch, [switch]$Preview) {
  Write-Section "== Sync $BaseBranch =="
  if ($Preview) {
    Info ("git switch {0}" -f $BaseBranch)
    Info ("git pull --ff-only origin {0}" -f $BaseBranch)
    return
  }
  git switch $BaseBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "git switch $BaseBranch failed." }
  git pull --ff-only origin $BaseBranch | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "git pull --ff-only failed." }
}

function DeleteLocalBranch([string]$Branch, [switch]$Preview) {
  Write-Section "== Delete local branch =="
  if ($Preview) {
    Info ("git branch -D -- {0}" -f $Branch)
    return
  }
  $cur = (git branch --show-current).Trim()
  if ($cur -eq $Branch) { Die "Refusing: currently on '$Branch'." }
  git branch -D -- $Branch | Out-Host
}

function MaybeTagGreen([switch]$DoTag, [switch]$Preview) {
  if (-not $DoTag) { return }
  $tag = ("green/{0:yyyyMMdd-HHmmss}" -f (Get-Date))
  Write-Section "== Tag green baseline ($tag) =="
  if ($Preview) {
    Info ("git tag -a {0} -m <message>" -f $tag)
    Info ("git push origin {0}" -f $tag)
    return
  }
  git tag -a $tag -m "Green baseline after jp-publish-work merge/sync" | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "git tag failed." }
  git push origin $tag | Out-Host
  if ($LASTEXITCODE -ne 0) { Die "git push tag failed." }
}

# ---------------- main ----------------
Require-Tool git
Require-Tool gh
Assert-RepoRootLocal -root $RepoRoot

Push-Location -LiteralPath $RepoRoot
try {
  # Require explicit mode selection
  if ($DryRun -and $Live) { Die "Refusing: choose exactly one mode: -DryRun OR -Live (not both)." }
  if (-not $DryRun -and -not $Live) { Die "Refusing: you must specify -DryRun OR -Live." }
  $preview = $DryRun

  # Repo slug
  if ($Repo -eq 'AUTO' -or -not $Repo) { $Repo = Get-RepoSlugFromOrigin }

  # Auth visibility
  if ($ShowAuthStatus) { & gh auth status 2>&1 | Out-Host }

  Ensure-GhAuth -Preview:$preview
  Ensure-RemoteUpdated

  $curBranch = Get-CurrentBranch
  $dirty = @(Get-DirtyStatusLines)
  $isDirty = ($dirty -and $dirty.Count -gt 0)
  $isBase  = ($curBranch -eq $Base)
  $isWork  = ($curBranch -like 'work/*')

  $ahead = 0
  try { $ahead = Get-CommitCountVsBase -BaseBranch $Base -Branch $curBranch } catch { $ahead = 0 }

  Write-Section "== Summary =="
  Info ("Repo:   {0}" -f $Repo)
  Info ("Branch: {0}" -f $curBranch)
  Info ("Base:   {0}" -f $Base)
  Info ("Ahead vs base: {0}" -f $ahead)
  Info ("Dirty:  {0}" -f ($(if ($isDirty) { 'YES' } else { 'NO' })))
  Info ("Mode:   {0}" -f ($(if ($preview) { 'DRYRUN' } else { 'LIVE' })))

  # --- DRYRUN relaxations ---
  if ($preview) {
    if ($isBase) { Warn ("DRYRUN: running on base branch '{0}' (allowed). Would refuse in LIVE." -f $Base) }
    if (-not $isWork) { Warn ("DRYRUN: branch '{0}' does not match work/* (allowed). Would refuse in LIVE." -f $curBranch) }
    if ($isDirty) {
      Warn "DRYRUN: working tree is dirty (allowed). Would refuse in LIVE. Status:"
      $dirty | ForEach-Object { Warn ("  {0}" -f $_) }
    }
    if ($ahead -lt 1) { Warn ("DRYRUN: ahead=0 vs base (allowed). PR create would be refused in LIVE (prevents no-commit PR loop).") }

    # Only proceed to PR preview steps if this is a publishable scenario
    $canPreviewPublish = (-not $isBase) -and $isWork -and ($ahead -ge 1)

    if (-not $canPreviewPublish) {
      Write-Section "== DRYRUN: stop (not publishable) =="
      Warn "DRYRUN will not attempt PR create/edit/merge from this state."
      Warn "To preview full publish flow: switch to a work/* branch with at least 1 commit vs base."
      Write-Host ""
      Write-Host "DRYRUN: done (no mutations performed)." -ForegroundColor Green
      return
    }
  }

  # --- LIVE strict guards ---
  if (-not $preview) {
    if ($isBase) { Die ("Refusing: currently on '{0}'. Checkout a work/* branch first." -f $Base) }
    if (-not $isWork) { Die ("Refusing: branch must match 'work/*' (current: '{0}')." -f $curBranch) }
    if ($isDirty) { Die ("Refusing: working tree is dirty. Commit/stash first.`n{0}" -f ($dirty -join "`n")) }
    if ($ahead -lt 1) { Die ("Refusing: no commits between {0} and {1} (ahead={2}). This prevents the no-commit PR loop." -f $Base, $curBranch, $ahead) }
  }

  # Push (safe)
  Write-Section "== Push current branch (safe) =="
  if ($preview) {
    Info ("DRYRUN: git push -u origin {0}" -f $curBranch)
  } else {
    git push -u origin $curBranch | Out-Host
    if ($LASTEXITCODE -ne 0) { Die "git push failed." }
  }

  $prNum = Get-OrCreatePR -RepoFull $Repo -HeadBranch $curBranch -BaseBranch $Base -MaybeTitle $Title -MaybeBody $Body -Preview:$preview
  if ($prNum -eq 0 -and $preview) {
    Write-Section "== DRYRUN complete =="
    Write-Host "DRYRUN: done (no mutations performed)." -ForegroundColor Green
    return
  }

  UpdatePRText -RepoFull $Repo -PrNum $prNum -MaybeTitle $Title -MaybeBody $Body -Preview:$preview
  WatchChecks -RepoFull $Repo -PrNum $prNum -SkipWatch:$NoWatch -Preview:$preview
  MergePR -RepoFull $Repo -PrNum $prNum -Preview:$preview
  SyncBase -BaseBranch $Base -Preview:$preview
  DeleteLocalBranch -Branch $curBranch -Preview:$preview
  MaybeTagGreen -DoTag:$TagGreenBaseline -Preview:$preview

  Write-Section "== Final status =="
  if ($preview) {
    Write-Host "DRYRUN: done (no mutations performed)." -ForegroundColor Green
  } else {
    git status | Out-Host
    git log -1 --oneline | Out-Host
    Write-Host ""
    Write-Host "Done." -ForegroundColor Green
  }
}
finally {
  Pop-Location
}
