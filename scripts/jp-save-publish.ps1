Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Step([string]$n,[scriptblock]$sb){
  Write-Host ""
  Write-Host ("=== {0} ===" -f $n) -ForegroundColor Cyan
  try { & $sb; Write-Host ("PASS: {0}" -f $n) -ForegroundColor Green }
  catch { Write-Host ("FAIL: {0}" -f $n) -ForegroundColor Red; throw }
}

param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$ReleasePrefix = 'jp-save',
  [switch]$OpenRelease
)

Set-Location -LiteralPath $RepoRoot

$saveScript = Join-Path $RepoRoot 'scripts\jp-save.ps1'
if (-not (Test-Path -LiteralPath $saveScript)) { throw ("Missing: {0}" -f $saveScript) }

Step 'RUN jp-save.ps1 (produce artifacts)' {
  $out = & $saveScript 2>&1 | ForEach-Object { $_.ToString() }
  $out | ForEach-Object { Write-Host $_ }

  # Parse: Zip:, Zip+:, Mark:, SHA:
  $zipLine    = $out | Where-Object { $_ -match '^\s*Zip:\s+'  } | Select-Object -First 1
  $zipPlusLine= $out | Where-Object { $_ -match '^\s*Zip\+:\s+'} | Select-Object -First 1
  $markLine   = $out | Where-Object { $_ -match '^\s*Mark:\s+' } | Select-Object -First 1
  $shaLine    = $out | Where-Object { $_ -match '^\s*SHA:\s+'  } | Select-Object -First 1

  $Zip    = if ($zipLine)     { ($zipLine     -replace '^\s*Zip:\s+','').Trim() } else { $null }
  $ZipPlus= if ($zipPlusLine) { ($zipPlusLine -replace '^\s*Zip\+:\s+','').Trim() } else { $null }
  $Mark   = if ($markLine)    { ($markLine    -replace '^\s*Mark:\s+','').Trim() } else { $null }
  $Sha    = if ($shaLine)     { ($shaLine     -replace '^\s*SHA:\s+','').Trim() } else { $null }

  if (-not $Zip -and -not $ZipPlus) { throw "Could not parse Zip/Zip+ from jp-save output." }

  # Prefer timestamped Zip+ as the primary release artifact
  $PrimaryZip = if ($ZipPlus) { $ZipPlus } else { $Zip }

  foreach ($p in @($PrimaryZip,$Zip,$Mark,$Sha) | Where-Object { $_ }) {
    if (-not (Test-Path -LiteralPath $p)) { throw ("Artifact missing: {0}" -f $p) }
  }

  Set-Variable -Name JP_PRIMARY_ZIP -Value $PrimaryZip -Scope Script
  Set-Variable -Name JP_ZIP_LATEST  -Value $Zip        -Scope Script
  Set-Variable -Name JP_MARK        -Value $Mark       -Scope Script
  Set-Variable -Name JP_SHA         -Value $Sha        -Scope Script
}

Step 'CREATE GitHub Release + UPLOAD assets' {
  # timestamp tag
  $ts  = Get-Date -Format 'yyyyMMdd-HHmmss'
  $tag = "{0}-{1}" -f $ReleasePrefix, $ts
  $title = "JP Engine Save {0}" -f $ts

  $assets = @($JP_PRIMARY_ZIP)
  if ($JP_ZIP_LATEST) { $assets += $JP_ZIP_LATEST }
  if ($JP_MARK)       { $assets += $JP_MARK }
  if ($JP_SHA)        { $assets += $JP_SHA }

  # Create release (fails hard if it can't)
  gh release create $tag --title $title --notes "Automated save snapshot from jp-save.ps1" | Out-Host

  # Upload assets (explicit; fail hard on any error)
  foreach ($a in $assets) {
    gh release upload $tag $a --clobber | Out-Host
  }

  Write-Host ("Release created: tag={0}" -f $tag) -ForegroundColor DarkCyan
  Set-Variable -Name JP_RELEASE_TAG -Value $tag -Scope Script
}

if ($OpenRelease) {
  Step 'OPEN Release in browser' {
    gh release view $JP_RELEASE_TAG --web | Out-Null
  }
}

Write-Host ""
Write-Host "🟢 JP Save + Publish: COMPLETE (release created + assets uploaded)." -ForegroundColor Green
