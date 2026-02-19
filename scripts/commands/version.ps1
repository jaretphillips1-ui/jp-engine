@{
  Name = "version"
  Description = "Show version"
  Action = {
    $sha = ""
    try { $sha = (git rev-parse --short HEAD).Trim() } catch { $sha = "" }
    if (-not $sha) { $sha = "unknown" }
    "jp-engine {0}" -f $sha
  }
}
