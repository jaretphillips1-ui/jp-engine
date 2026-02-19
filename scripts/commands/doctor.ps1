@{
  Name = "doctor"
  Description = "Run jp-doctor (optional)"
  Action = {
    $d = "$PSScriptRoot\..\jp-doctor.ps1"
    if(Test-Path $d){ & $d }
  }
}
