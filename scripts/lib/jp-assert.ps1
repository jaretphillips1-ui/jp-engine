Set-StrictMode -Version Latest

function Assert-RepoRoot {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [switch]$SetLocation
  )

  # Normalize (handles forward/back slashes + case-ish)
  $expected = [System.IO.Path]::GetFullPath($RepoRoot.Trim())
  $pwdPath  = [System.IO.Path]::GetFullPath((Get-Location).Path)

  if ($SetLocation) {
    Set-Location -LiteralPath $expected
    $pwdPath = [System.IO.Path]::GetFullPath((Get-Location).Path)
  }

  if ($pwdPath -ne $expected) {
    throw "Repo root gate failed. PWD='$pwdPath' Expected='$expected'"
  }

  if (-not (Test-Path -LiteralPath (Join-Path $expected '.git'))) {
    throw "Repo root gate failed: .git not found at '$expected'"
  }
}

function Assert-CleanTree {
  [CmdletBinding()]
  param(
    [switch]$AllowUntracked
  )

  # Porcelain output: empty means clean
  $porcelain = git status --porcelain 2>$null
  if ($LASTEXITCODE -ne 0) { throw "git status failed" }

  if (-not $porcelain) { return }

  if ($AllowUntracked) {
    $dirty = $porcelain | Where-Object { $_ -notmatch '^\?\?' }
    if (-not $dirty) { return }
  }

  throw "Working tree is not clean. Run: git status --porcelain"
}

Export-ModuleMember -Function Assert-RepoRoot, Assert-CleanTree -ErrorAction SilentlyContinue
