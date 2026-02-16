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

# Global loosening knobs:
# - JP_ASCII=1    => ASCII '='
# - JP_COMPACT=1  => reduce thickness + simpler look
$useAscii  = $Ascii -or ($env:JP_ASCII -eq "1")
$compact   = ($env:JP_COMPACT -eq "1")

# Compact mode: cap thickness to keep output lighter.
if ($compact) { $Thick = [Math]::Min($Thick, 3) }

$lineChar = if ($useAscii) { "=" } else { "═" }

# Color via Write-Host -ForegroundColor (no ANSI escapes)
$fg = $null
if ($Color) {
  if ($Pass) { $fg = 'Green' }
  elseif ($Warn) { $fg = 'Yellow' }
  elseif ($Fail) { $fg = 'Red' }
  else { $fg = 'Cyan' }
}

# Stoplight icon prefix (auto-added when using Pass/Warn/Fail)
$icon = ""
if ($Pass) { $icon = "🟢 " }
elseif ($Warn) { $icon = "🟡 " }
elseif ($Fail) { $icon = "🔴 " }

$line = ($lineChar * $w)

$labelText = $Label.Trim()
if ($labelText) {
  $labelLine = "  $icon$labelText  "

  # Compact: don't try to perfectly center; keep it readable.
  if ($compact) {
    if ($labelLine.Length -gt $w) { $labelLine = $labelLine.Substring(0, $w) }
  } else {
    if ($labelLine.Length -lt $w) {
      $padTotal = $w - $labelLine.Length
      $padLeft  = [Math]::Floor($padTotal / 2)
      $padRight = $padTotal - $padLeft
      $labelLine = ($lineChar * $padLeft) + $labelLine + ($lineChar * $padRight)
    } else {
      $labelLine = $labelLine.Substring(0, $w)
    }
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
