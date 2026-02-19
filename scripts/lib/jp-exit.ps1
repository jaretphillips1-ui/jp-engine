Set-StrictMode -Version Latest

# Exit code conventions (keep small + stable)
# 0 = success
# 1 = general failure
# 2 = usage/args error
# 3 = dependency missing

function JP-Exit {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][int]$Code,
    [string]$Message = ''
  )

  if ($Message) {
    try { JP-Log -Level ERROR -Message $Message } catch { Write-Host $Message }
  }

  exit $Code
}
