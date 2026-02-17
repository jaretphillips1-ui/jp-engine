<#
JP Doctor — fast, repo-scoped health + security checks

Design goals:
- HARD GATE: only runs inside C:\Dev\JP_ENGINE\jp-engine
- NEVER scans outside repo
- Summarizes PASS/FAIL and exits non-zero on failure (CI-friendly)
- Builds on scripts\jp-verify.ps1 (known-good baseline)
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

function Write-Ok([string]$Msg)   { Write-Host ("[OK]  " + $Msg) }
function Write-Warn([string]$Msg) { Write-Host ("[WARN] " + $Msg) }
function Write-Fail([string]$Msg) { Write-Host ("[FAIL] " + $Msg) }

function Require-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "Required command not found in PATH: $Name" }
  return $cmd
}

function Try-Command([string]$Name) {
  return (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-RepoRoot() {
  $git = Try-Command "git"
  if (-not $git) { throw "git is required." }

  $root = (& git rev-parse --show-toplevel 2>$null)
  if (-not $root) { throw "Not inside a git repository (git rev-parse failed)." }
  return ($root.Trim())
}

function Assert-InRepo([string]$RepoRoot) {
  $expected = "C:\Dev\JP_ENGINE\jp-engine"
  $normRepo = (Resolve-Path -LiteralPath $RepoRoot).Path
  $normExpected = (Resolve-Path -LiteralPath $expected).Path

  if ($normRepo -ne $normExpected) {
    throw "Safety gate: Repo root is '$normRepo' but expected '$normExpected'. Refusing to run."
  }
}

function Run-Step([string]$Name, [scriptblock]$Action, [ref]$Failures) {
  try {
    if ($VerboseOutput) { Write-Host "-> $Name" }
    & $Action
    Write-Ok $Name
  }
  catch {
    $Failures.Value++
    Write-Fail ("{0}`n       {1}" -f $Name, $_.Exception.Message)
    if ($VerboseOutput) {
      Write-Host $_.ScriptStackTrace
    }
  }
}

function Test-FileContainsLine([string]$Path, [string]$PatternRegex) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $txt = Get-Content -LiteralPath $Path -Raw
  return ($txt -match $PatternRegex)
}

# --- Start ---
Write-Section "JP Doctor (repo-scoped) — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Require-Command "git"  | Out-Null
Require-Command "pwsh" | Out-Null

$failures = 0

$repoRoot = Get-RepoRoot
Assert-InRepo -RepoRoot $repoRoot

# Safety: force working directory to repo root for all steps.
Set-Location -LiteralPath $repoRoot

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
$commit = (& git rev-parse --short HEAD).Trim()
$statusCount = @(& git status --porcelain).Count

Write-Host "Repo root: $repoRoot"
Write-Host "Branch:    $branch"
Write-Host "Commit:    $commit"
Write-Host "Status:    $statusCount change(s)"

Write-Section "1) Baseline verify (scripts\jp-verify.ps1)"

Run-Step "Run jp-verify.ps1" ([scriptblock]{
  $verify = Join-Path $repoRoot "scripts\jp-verify.ps1"
  if (-not (Test-Path -LiteralPath $verify)) { throw "Missing: $verify" }
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $verify
}) ([ref]$failures)

Write-Section "2) Repo hygiene (ignore rules, dangerous files, secrets quick checks)"

Run-Step ".gitignore sanity checks" ([scriptblock]{
  $gi = Join-Path $repoRoot ".gitignore"
  if (-not (Test-Path -LiteralPath $gi)) { throw "Missing .gitignore at repo root." }

  $mustHave = @(
    '(^|/)\.env(\..*)?$',
    '\.env\.local',
    '\.DS_Store',
    'node_modules',
    '\.vercel',
    '\.netlify',
    'dist',
    'build',
    '\.next',
    '\.zip$'
  )

  foreach ($rx in $mustHave) {
    if (-not (Test-FileContainsLine -Path $gi -PatternRegex $rx)) {
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

Run-Step "Quick grep for common secret markers (repo-scoped, exclude doctor script)" ([scriptblock]{
  # IMPORTANT:
  # - We exclude scripts/jp-doctor.ps1 so the pattern list itself doesn't trigger a false failure.
  # - This is just a fast “tripwire”. gitleaks is the real leak scanner.
  $exclude = ":(exclude)scripts/jp-doctor.ps1"

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
    $out = (& git grep -n --ignore-case -E $n -- . $exclude 2>$null)
    if ($out) {
      throw "Possible secret pattern match for '$n':`n$($out -join "`n")"
    }
  }
}) ([ref]$failures)

Write-Section "3) Pro scanners (repo only)"

if (-not $NoGitleaks) {
  Run-Step "Gitleaks detect (repo-scoped)" ([scriptblock]{
    $gitleaks = Try-Command "gitleaks"
    if (-not $gitleaks) {
      Write-Warn "gitleaks not found in PATH. Skipping. (Install recommended)"
      return
    }

    # --source . => repo only
    # --redact => do not print secret values
    # --exit-code 1 => fail on findings
    & gitleaks detect --source "." --redact --no-banner --exit-code 1
  }) ([ref]$failures)
}
else {
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
}
else {
  Write-Warn "Skipping semgrep (NoSemgrep)"
}

Write-Section "4) Node checks (audit + tests/lint if present)"

if (-not $NoNpmAudit) {
  Run-Step "npm audit (package-lock required)" ([scriptblock]{
    $npm = Try-Command "npm"
    if (-not $npm) {
      Write-Warn "npm not found. Skipping npm audit."
      return
    }

    $pkg = Join-Path $repoRoot "package.json"
    if (-not (Test-Path -LiteralPath $pkg)) {
      Write-Warn "No package.json at repo root. Skipping npm audit."
      return
    }

    $lock = Join-Path $repoRoot "package-lock.json"
    if (-not (Test-Path -LiteralPath $lock)) {
      Write-Warn "No package-lock.json found. Consider committing one for consistent audits."
      return
    }

    & npm audit --audit-level=moderate
  }) ([ref]$failures)
}
else {
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
    }
    else {
      Write-Warn "No npm script: test"
    }

    if ($scripts.PSObject.Properties.Name -contains "lint") {
      & npm run lint
    }
    else {
      Write-Warn "No npm script: lint"
    }
  }) ([ref]$failures)
}
else {
  Write-Warn "Skipping npm scripts (NoNpmScripts)"
}

Write-Section "Result"

if ($failures -eq 0) {
  Write-Ok "JP Doctor PASSED (0 failures)"
  exit 0
}
else {
  Write-Fail "JP Doctor FAILED ($failures failure(s))"
  Write-Host ""
  Write-Host "Next actions:"
  Write-Host " - Fix the FAIL items above, then re-run:"
  Write-Host "     pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\jp-doctor.ps1"
  Write-Host " - If you need to temporarily skip a scanner:"
  Write-Host "     .\scripts\jp-doctor.ps1 -NoGitleaks -NoSemgrep"
  exit 1
}
