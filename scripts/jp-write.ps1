param(
  [Parameter(Mandatory)]
  [string]$Path,

  [Parameter(Mandatory)]
  [string]$Content,

  [switch]$Stage,

  [switch]$RequireParamFirst
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
  throw ("jp-write: " + $Message)
}

function Normalize-ToLf([string]$Text) {
  return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Get-AbsolutePath([string]$InputPath) {
  # If rooted, keep it. If relative, make it relative to the current repo root (Get-Location).
  if ([System.IO.Path]::IsPathRooted($InputPath)) {
    return $InputPath
  }
  $base = (Get-Location).Path
  return (Join-Path -Path $base -ChildPath $InputPath)
}

function Write-Utf8NoBomLf([string]$InputPath, [string]$Text) {
  $abs = Get-AbsolutePath $InputPath
  $lf  = Normalize-ToLf $Text
  $enc = New-Object System.Text.UTF8Encoding($false) # no BOM

  $parent = Split-Path -Parent $abs
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    Fail ("Parent folder does not exist: " + $parent)
  }

  [System.IO.File]::WriteAllText($abs, $lf, $enc)
}

function Assert-ParamFirst([string]$InputPath) {
  $abs = Get-AbsolutePath $InputPath
  $lines = Get-Content -LiteralPath $abs
  $first = ($lines | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1)
  if (-not $first) { Fail "File is empty." }
  if (-not $first.Trim().StartsWith("param(")) {
    Fail ("First non-empty line must start with 'param(' but was: " + $first.Trim())
  }
}

function Stage-WithSafeCrlfFallback([string]$InputPath) {
  $origSafeCrlf = (git config --local core.safecrlf)

  try {
    git add -- $InputPath
    return
  } catch {
    git config --local core.safecrlf warn | Out-Null
    try {
      git add -- $InputPath
    } finally {
      if ($null -ne $origSafeCrlf -and $origSafeCrlf -ne "") {
        git config --local core.safecrlf $origSafeCrlf | Out-Null
      } else {
        git config --local --unset core.safecrlf 2>$null | Out-Null
      }
    }
  }
}

# Guard: refuse obvious placeholder junk
if ($Content -match 'REPLACE_ME|TODO:PLACEHOLDER|<PASTE HERE>') {
  Fail "Refusing to write placeholder content."
}

Write-Utf8NoBomLf -InputPath $Path -Text $Content

if ($RequireParamFirst) {
  Assert-ParamFirst -InputPath $Path
}

if ($Stage) {
  Stage-WithSafeCrlfFallback -InputPath $Path
}

Write-Host ("jp-write: wrote " + $Path + " (utf8-noBOM + LF)" + ($(if ($Stage) { " + staged" } else { "" })))
