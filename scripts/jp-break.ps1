[CmdletBinding()]
param(
  [int]$Thick = 6,
  [switch]$Color,
  [switch]$Pass,
  [switch]$Fail,
  [switch]$Bold,
  [string]$Label = ""
)

$w = 80
try { $w = [Math]::Max(40, $Host.UI.RawUI.WindowSize.Width) } catch { }

$fg = $null
if ($Color) {
  if ($Pass) { $fg = 'Green' }
  elseif ($Fail) { $fg = 'Red' }
  else { $fg = 'Cyan' }
}

$lineChar = "═"
$line = ($lineChar * $w)

$labelText = $Label.Trim()
if ($labelText) {
  $labelLine = "  $labelText  "
  if ($labelLine.Length -lt $w) {
    $padTotal = $w - $labelLine.Length
    $padLeft  = [Math]::Floor($padTotal / 2)
    $padRight = $padTotal - $padLeft
    $labelLine = ($lineChar * $padLeft) + $labelLine + ($lineChar * $padRight)
  } else {
    $labelLine = $labelLine.Substring(0, $w)
  }
}

function Format-Bold([string]$s) {
  if (-not $Bold) { return $s }
  try { return "$($PSStyle.Bold)$s$($PSStyle.Reset)" } catch { return $s }
}

for ($i = 0; $i -lt $Thick; $i++) {
  if ($labelText -and $i -eq [Math]::Floor(($Thick - 1) / 2)) { $out = Format-Bold $labelLine }
  else { $out = Format-Bold $line }

  if ($fg) { Write-Host $out -ForegroundColor $fg } else { Write-Host $out }
}