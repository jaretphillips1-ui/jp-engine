[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command = '',
  [switch]$Version,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\jp-log.ps1"
. "$PSScriptRoot\lib\jp-exit.ps1"

function Import-JPCommandDefs {
  [CmdletBinding()]
  param([string]$CommandsDir)

  $map = @{}
  if (-not (Test-Path -LiteralPath $CommandsDir)) { return $map }

  $files = Get-ChildItem -LiteralPath $CommandsDir -Filter '*.ps1' -File | Sort-Object Name
  foreach ($f in $files) {
    $def = $null
    try {
      # Each command file should OUTPUT a hashtable like:
      # @{ Name="x"; Description="..."; Action={ ... } }
      $def = & $f.FullName
    } catch {
      JP-Log -Level ERROR -Message ("Command load failed: {0} :: {1}" -f $f.FullName, $_.Exception.Message)
      continue
    }

    if ($null -eq $def -or $def -isnot [hashtable]) {
      JP-Log -Level WARN -Message ("Skip (not a hashtable): {0}" -f $f.Name)
      continue
    }

    $name = [string]$def.Name
    if ([string]::IsNullOrWhiteSpace($name)) {
      JP-Log -Level WARN -Message ("Skip (missing Name): {0}" -f $f.Name)
      continue
    }

    if (-not $def.ContainsKey('Description')) { $def.Description = "" }
    if (-not $def.ContainsKey('Action') -or ($def.Action -isnot [scriptblock])) {
      JP-Log -Level WARN -Message ("Skip (missing Action scriptblock): {0}" -f $f.Name)
      continue
    }

    $map[$name] = $def
  }

  return $map
}

function Invoke-JPCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][hashtable]$Registry
  )

  if (-not $Registry.ContainsKey($Name)) {
    if ($Registry.ContainsKey('help')) {
      # Try to show help if available
      try {
        $helpAction = $Registry['help'].Action
        & $helpAction $Registry
      } catch {}
    }
    JP-Exit -Code 2 -Message ("Unknown command: {0}" -f $Name)
  }

  $action = $Registry[$Name].Action

  try {
    $paramCount = 0
    try { $paramCount = $action.Ast.ParamBlock.Parameters.Count } catch { $paramCount = 0 }

    if ($paramCount -ge 1) {
      & $action $Registry
    } else {
      & $action
    }
  } catch {
    JP-Exit -Code 1 -Message ("Command failed: {0} :: {1}" -f $Name, $_.Exception.Message)
  }
}

JP-Banner -Title "JP ENGINE — CLI"

# Build registry from scripts/commands
$Commands = @{}
$dynDir = Join-Path $PSScriptRoot 'commands'
$dyn = Import-JPCommandDefs -CommandsDir $dynDir
foreach ($k in $dyn.Keys) { $Commands[$k] = $dyn[$k] }

# Back-compat switches
if ($Version) { $Command = "version" }
if ($Help)    { $Command = "help" }
if (-not $Command) { $Command = "help" }

Invoke-JPCommand -Name $Command -Registry $Commands
JP-Exit -Code 0
