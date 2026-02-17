<#
JP Doctor — fast, repo-scoped health + security checks

Design goals:
- HARD SAFETY GATE: only runs in approved repo roots (local dev OR CI workspace)
- NEVER scans outside repo
- Summarizes PASS/FAIL and exits non-zero on failure (CI-friendly)
- Builds on scripts\jp-verify.ps1 (known-good baseline)

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1

Optional switches:
  -NoGitleaks    Skip gitleaks scan
  -NoSemgrep     Skip semgrep scan
  -NoNpmAudit    Skip npm audit
  -NoNpmScripts  Skip npm test/lint checks
  -VerboseOutput More details on failures
#>

[CmdletBinding()]
param(
  [switch]$NoGitleaks,
  [switch]$NoSemgrep,
  [switch]$NoNpmAudit,
  [switch]$NoNpmScripts,
  [switch]$VerboseOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section([string]$Title) {
  Write-Host ""
  Write-Host ("=" * 78)
  Write-Host $Title
  Write-Host ("=" * 78)
}

function Write-Ok([string]$Msg)   { Write-Host ("[OK]   " + $Msg) }
function Write-Warn([string]$Msg) { Write-Host ("[WARN] " + $Msg) }
function Write-Fail([string]$Msg) { Write-Host ("[FAIL] " + $Msg) }

function Try-Command([string]$Name) {
  return (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Require-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Required command not found in PATH: $Name" }
  return $cmd
}

function Get-RepoRoot() {
  # Prefer git repo root if available (repo-scoped and robust),
  # else fall back to script location.
  $git = Try-Command "git"
  if ($git) {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($root) { return ($root.Trim()) }
  }
  return (Resolve-Path "$PSScriptRoot\..").Path
}

function Get-NormalizedPath([string]$Path) {
  try {
    return (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
  } catch {
    return $Path.TrimEnd('\')
  }
}

function Assert-InAllowedRepo([string]$RepoRoot) {
  $normRepo = Get-NormalizedPath $RepoRoot

  # Local dev canonical expected root
  $localExpected = "C:\Dev\JP_ENGINE\jp-engine"

  # Allowed roots = localExpected + (CI workspace if present)
  $allowed = @()
  $allowed += (Get-NormalizedPath $localExpected)

  if ($env:GITHUB_WORKSPACE) {
    $allowed += (Get-NormalizedPath $env:GITHUB_WORKSPACE)
  }

  $allowed = $allowed | Select-Object -Unique

  if ($allowed -notcontains $normRepo) {
    throw "Safety gate: Repo root is '$normRepo' but expected one of: $($allowed -join ', '). Refusing to run."
  }

  return $normRepo
}

function Run-Step([string]$Name, [scriptblock]$Action, [ref]$Failures) {
  try {
    if ($VerboseOutput) { Write-Host "-> $Name" }
    & $Action
    Write-Ok $Name
  } catch {
    $Failures.Value++
    Write-Fail ("{0}`n       {1}" -f $Name, $_.Exception.Message)
    if ($VerboseOutput) {
      Write-Host $_.ScriptStackTrace
    }
  }
}

function Get-TextLines([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  return Get-Content -LiteralPath $Path -ErrorAction Stop
}

function Gitignore-HasLineMatch([string]$GitignorePath, [string]$PatternRegex) {
  # Match LINE-BY-LINE so ^ and $ mean start/end of line (not whole file).
  # Ignore blank/comment-only lines.
  $lines = Get-TextLines -Path $GitignorePath
  foreach ($line in $lines) {
    $l = $line.Trim()
    if ($l.Length -eq 0) { continue }
    if ($l.StartsWith("#")) { continue }
    if ($l -match $PatternRegex) { return $true }
  }
  return $false
}

# ---------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------

Write-Section "JP Doctor (repo-scoped) — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Require-Command "pwsh" | Out-Null
Require-Command "git"  | Out-Null

$failures = 0

$repoRootRaw = Get-RepoRoot
$repoRoot = Assert-InAllowedRepo -RepoRoot $repoRootRaw

Set-Location -LiteralPath $repoRoot

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
$commit = (& git rev-parse --short HEAD).Trim()
$statusCount = @(& git status --porcelain).Count

Write-Host "Repo root: $repoRoot"
Write-Host "Branch:    $branch"
Write-Host "Commit:    $commit"
Write-Host "Status:    $statusCount change(s)"

# ---------------------------------------------------------------------
# 1) Baseline verify
# ---------------------------------------------------------------------

Write-Section "1) Baseline verify (scripts\jp-verify.ps1)"

Run-Step "Run jp-verify.ps1" ([scriptblock]{
  $verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
  if (-not (Test-Path -LiteralPath $verify)) { throw "Missing: $verify" }
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
}) ([ref]$failures)

# ---------------------------------------------------------------------
# 2) Repo hygiene checks (repo-scoped)
# ---------------------------------------------------------------------

Write-Section "2) Repo hygiene (ignore rules, dangerous files, secrets quick checks)"

Run-Step ".gitignore sanity checks" ([scriptblock]{
  $gi = Join-Path $repoRoot ".gitignore"
  if (-not (Test-Path -LiteralPath $gi)) { throw "Missing .gitignore at repo root." }

  # Recommended patterns; WARN only.
  $recommended = @(
    '(^|/)\.env(\..*)?$',
    '\.env\.local$',
    'node_modules/?$',
    '\.vercel/?$',
    '\.netlify/?$',
    'dist/?$',
    'build/?$',
    '\.next/?$',
    '\.zip$'
  )

  foreach ($rx in $recommended) {
    if (-not (Gitignore-HasLineMatch -GitignorePath $gi -PatternRegex $rx)) {
      Write-Warn "Recommended ignore missing (regex): $rx"
    }
  }
}) ([ref]$failures)

Run-Step "Block obvious dangerous tracked files (keys/certs/env)" ([scriptblock]{
  $patterns = @(
    "*.pem","*.key","*.p12","*.pfx","*.crt","*.cer",
    ".env",".env.*",
    "*id_rsa*","*id_ed25519*"
  )

  foreach ($p in $patterns) {
    $hits = (& git ls-files -- $p 2>$null)
    if ($hits) {
      throw "Tracked sensitive file(s) matching '$p':`n$($hits -join "`n")"
    }
  }
}) ([ref]$failures)

Run-Step "Quick grep for common secret markers (repo-scoped)" ([scriptblock]{
  $needles = @(
    'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_ACCESS_KEY_ID',
    'xox[baprs]-',        # Slack tokens
    'ghp_',               # GitHub classic tokens
    'github_pat_',        # GitHub fine-grained tokens
    'AIzaSy',             # Google API keys (common prefix)
    '-----BEGIN PRIVATE KEY-----'
  )

  foreach ($n in $needles) {
    # IMPORTANT:
    # Exclude this doctor script itself, otherwise the needle list causes a self-hit.
    $out = (& git grep -n --ignore-case -E $n -- . ":(exclude)scripts/jp-doctor.ps1" 2>$null)
    if ($out) {
      throw "Possible secret pattern match for '$n':`n$($out -join "`n")"
    }
  }
}) ([ref]$failures)

# ---------------------------------------------------------------------
# 3) Pro scanners (repo only)
# ---------------------------------------------------------------------

Write-Section "3) Pro scanners (repo only)"

if (-not $NoGitleaks) {
  Run-Step "Gitleaks detect (repo-scoped, if installed)" ([scriptblock]{
    $gitleaks = Try-Command "gitleaks"
    if (-not $gitleaks) {
      Write-Warn "gitleaks not found in PATH. Skipping. (Install recommended)"
      return
    }
    & gitleaks detect --source "." --redact --no-banner --exit-code 1
  }) ([ref]$failures)
} else {
  Write-Warn "Skipping gitleaks (NoGitleaks)"
}

if (-not $NoSemgrep) {
  Run-Step "Semgrep scan (repo-scoped, if installed)" ([scriptblock]{
    $semgrep = Try-Command "semgrep"
    if (-not $semgrep) {
      Write-Warn "semgrep not found in PATH. Skipping. (Install optional)"
      return
    }
    & semgrep --config auto --error --quiet
  }) ([ref]$failures)
} else {
  Write-Warn "Skipping semgrep (NoSemgrep)"
}

# ---------------------------------------------------------------------
# 4) Node checks (audit + tests/lint if present)
# ---------------------------------------------------------------------

Write-Section "4) Node checks (audit + scripts if present)"

if (-not $NoNpmAudit) {
  Run-Step "npm audit (package-lock required)" ([scriptblock]{
    $npm = Try-Command "npm"
    if (-not $npm) { Write-Warn "npm not found. Skipping npm audit."; return }

    $pkg = Join-Path $repoRoot "package.json"
    if (-not (Test-Path -LiteralPath $pkg)) { Write-Warn "No package.json at repo root. Skipping npm audit."; return }

    $lock = Join-Path $repoRoot "package-lock.json"
    if (-not (Test-Path -LiteralPath $lock)) { Write-Warn "No package-lock.json found. Consider committing one for consistent audits."; return }

    & npm audit --audit-level=moderate
  }) ([ref]$failures)
} else {
  Write-Warn "Skipping npm audit (NoNpmAudit)"
}

if (-not $NoNpmScripts) {
  Run-Step "npm scripts (test/lint if they exist)" ([scriptblock]{
    $npm = Try-Command "npm"
    if (-not $npm) { Write-Warn "npm not found. Skipping."; return }

    $pkgPath = Join-Path $repoRoot "package.json"
    if (-not (Test-Path -LiteralPath $pkgPath)) { Write-Warn "No package.json. Skipping."; return }

    $pkgJson = Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json
    $scripts = $pkgJson.scripts
    if ($null -eq $scripts) { Write-Warn "No scripts section in package.json. Skipping."; return }

    if ($scripts.PSObject.Properties.Name -contains "test") {
      & npm test
    } else {
      Write-Warn "No npm script: test"
    }

    if ($scripts.PSObject.Properties.Name -contains "lint") {
      & npm run lint
    } else {
      Write-Warn "No npm script: lint"
    }
  }) ([ref]$failures)
} else {
  Write-Warn "Skipping npm scripts (NoNpmScripts)"
}

# ---------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------

Write-Section "Result"

if ($failures -eq 0) {
  Write-Ok "JP Doctor PASSED (0 failures)"
  exit 0
} else {
  Write-Fail "JP Doctor FAILED ($failures failure(s))"
  Write-Host ""
  Write-Host "Next actions:"
  Write-Host " - Fix the FAIL items above, then re-run:"
  Write-Host "     pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1"
  Write-Host " - If you need to temporarily skip scanners:"
  Write-Host "     .\scripts\jp-doctor.ps1 -NoGitleaks -NoSemgrep"
  exit 1
}
