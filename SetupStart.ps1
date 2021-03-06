﻿function Log([string]$line, [string]$color = "Gray") {
    ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm", ":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"
}

Log "SetupStart, User: $env:USERNAME"

. (Join-Path $PSScriptRoot "settings.ps1")

if (!(Get-Package -Name Az -ErrorAction Ignore)) {
    Log "Installing Az PowerShell package"
    Install-Module -Name Az -Force -WarningAction Ignore | Out-Null
}

if (!(Get-Package -Name AzureAD -ErrorAction Ignore)) {
    Log "Installing AzureAD PowerShell package"
    Install-Package AzureAD -Force -WarningAction Ignore | Out-Null
}

$securePassword = ConvertTo-SecureString -String $adminPassword -Key $passwordKey
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword))

Log "Launch SetupVm"
$onceAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy UnRestricted -File c:\demo\setupVm.ps1"
Register-ScheduledTask -TaskName SetupVm `
    -Action $onceAction `
    -RunLevel Highest `
    -User $vmAdminUsername `
    -Password $plainPassword | Out-Null

Start-ScheduledTask -TaskName SetupVm
