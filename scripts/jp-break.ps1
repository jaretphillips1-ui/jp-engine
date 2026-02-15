[CmdletBinding()]
param(
  [int]$Thick = 6,
  [switch]$Color,
  [switch]$Pass,
  [switch]$Warn,
  [switch]$Fail,
  [switch]$Bold,
  [switch]$Ascii,
  [string]$Label = ""
)

$ErrorActionPreference = "Stop"

$w = 80
try { $w = [Math]::Max(40, $Host.UI.RawUI.WindowSize.Width) } catch { }

# Char set: box-drawing by default, ASCII fallback via -Ascii or JP_ASCII=1
$useAscii = $Ascii -or ($env:JP_ASCII -eq "1")
$lineChar = if ($useAscii) { "=" } else { "═" }

# Color is done via Write-Host -ForegroundColor (NOT ANSI escapes)
$fg = $null
if ($Color) {
  if ($Pass) { $fg = 'Green' }
  elseif ($Warn) { $fg = 'Yellow' }
  elseif ($Fail) { $fg = 'Red' }
  else { $fg = 'Cyan' }
}

# Stoplight icons (always visible if emoji renders)
$icon = ""
if ($Pass) { $icon = "🟢 " }
elseif ($Warn) { $icon = "🟡 " }
elseif ($Fail) { $icon = "🔴 " }

$line = ($lineChar * $w)

$labelText = $Label.Trim()
if ($labelText) {
  $labelLine = "  $icon$labelText  "
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
  # PSStyle bold uses ANSI; if host suppresses it, this safely degrades to plain text.
  try { return "$($PSStyle.Bold)$s$($PSStyle.Reset)" } catch { return $s }
}

for ($i = 0; $i -lt $Thick; $i++) {
  if ($labelText -and $i -eq [Math]::Floor(($Thick - 1) / 2)) { $out = Format-Bold $labelLine }
  else { $out = Format-Bold $line }

  if ($fg) { Write-Host $out -ForegroundColor $fg } else { Write-Host $out }
}
