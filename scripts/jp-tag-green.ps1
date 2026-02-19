param([switch]$RunSmoke)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$b = (git branch --show-current).Trim()
if ($b -ne "master") { throw "Must run on master." }

if (@(git status --porcelain).Count -ne 0) {
  throw "Master not clean."
}

$head = (git rev-parse --short HEAD).Trim()
$tag  = "baseline/green-" + (Get-Date -Format "yyyyMMdd-HHmm")

if ($RunSmoke) {
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\jp-smoke.ps1
}

git tag -a $tag -m "Green baseline @ $head"
git push origin $tag

"Tag created: $tag"
