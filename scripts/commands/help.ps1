@{
  Name = "help"
  Description = "Show help"
  Action = {
    param($Registry)

    Write-Host "JP Engine CLI"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  pwsh -File .\scripts\jp.ps1 <command>"
    Write-Host ""
    Write-Host "Commands:"
    foreach ($k in ($Registry.Keys | Sort-Object)) {
      Write-Host ("  {0,-10} {1}" -f $k, $Registry[$k].Description)
    }
  }
}
