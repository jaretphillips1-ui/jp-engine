Set-StrictMode -Version Latest

function JP-NowIso {
  (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

function JP-Log {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('INFO','WARN','ERROR','OK','STEP')] [string]$Level,
    [Parameter(Mandatory)][string]$Message
  )

  $ts = JP-NowIso
  $prefix = "[{0}] [{1}]" -f $ts, $Level

  switch ($Level) {
    'ERROR' { Write-Host ("{0} {1}" -f $prefix, $Message) -ForegroundColor Red }
    'WARN'  { Write-Host ("{0} {1}" -f $prefix, $Message) -ForegroundColor DarkYellow }
    'OK'    { Write-Host ("{0} {1}" -f $prefix, $Message) -ForegroundColor Green }
    'STEP'  { Write-Host ("{0} {1}" -f $prefix, $Message) -ForegroundColor Cyan }
    default { Write-Host ("{0} {1}" -f $prefix, $Message) }
  }
}

function JP-Banner {
  [CmdletBinding()]
  param([string]$Title = 'JP ENGINE')

  $line = ('=' * 78)
  Write-Host $line -ForegroundColor DarkGray
  JP-Log -Level STEP -Message $Title
  Write-Host $line -ForegroundColor DarkGray
}
