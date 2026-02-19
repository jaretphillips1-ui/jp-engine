Set-StrictMode -Version Latest

function Ensure-GhAuth {
  [CmdletBinding()]
  param(
    [Parameter()][switch] $ShowAuthStatus
  )

  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI ('gh') not found in PATH. Install it or fix PATH."
  }

  if ($ShowAuthStatus) {
    Write-Host ""
    Write-Host "=== GitHub CLI Auth Status ==="
    & gh auth status
    $code = $LASTEXITCODE
    Write-Host "=============================="
    if ($code -ne 0) {
      throw "GitHub CLI is not authenticated. Run: gh auth login"
    }
    return
  }

  # Quiet check: no banner noise
  & gh auth status 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
  }
}
