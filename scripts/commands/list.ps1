@{
  Name = "list"
  Description = "List available commands"
  Action = {
    param($Registry)
    ($Registry.Keys | Sort-Object) -join "`n"
  }
}
