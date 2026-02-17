param()

$ErrorActionPreference = "Stop"

Write-Host "============================================================="
Write-Host "JP Doctor (repo-scoped) — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "============================================================="

# ------------------------------------------------------------
# Resolve actual repo root (where script is being executed)
# ------------------------------------------------------------

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$normRepo = $repoRoot.Path.TrimEnd('\')

# ------------------------------------------------------------
# Define allowed repo roots
# ------------------------------------------------------------

$localExpected = "C:\Dev\JP_ENGINE\jp-engine"

$allowedRoots = @($localExpected)

if ($env:GITHUB_WORKSPACE) {
    $ciRoot = (Resolve-Path $env:GITHUB_WORKSPACE).Path.TrimEnd('\')
    $allowedRoots += $ciRoot
}

$allowedRoots = $allowedRoots | ForEach-Object {
    try {
        (Resolve-Path $_).Path.TrimEnd('\')
    } catch {
        $_.TrimEnd('\')
    }
}

# ------------------------------------------------------------
# Safety Gate
# ------------------------------------------------------------

if ($allowedRoots -notcontains $normRepo) {
    throw "Safety gate: Repo root is '$normRepo' but expected one of: $($allowedRoots -join ', '). Refusing to run."
}

Write-Host "Safety gate passed."
Write-Host "Repo root: $normRepo"
Write-Host ""

# ------------------------------------------------------------
# Begin Doctor Checks
# ------------------------------------------------------------

Write-Host "Running JP Doctor checks..."

# Example checks (extend as needed)

Write-Host "- Git version:"
git --version

Write-Host "- Node version:"
node --version

Write-Host "- NPM version:"
npm --version

Write-Host "- OpenSSL version:"
openssl version

Write-Host "- Gitleaks version:"
gitleaks version

Write-Host ""
Write-Host "JP Doctor completed successfully."
