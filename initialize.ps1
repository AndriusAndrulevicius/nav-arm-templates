# usage initialize.ps1
param
(
    [string] $templateLink = "https://raw.githubusercontent.com/Microsoft/nav-arm-templates/master/navdeveloperpreview.json",
    [string] $hostName = "",
    [string] $RemoteDesktopAccess = "*",
    [string] $vmAdminUsername = "vmadmin",
    [string] $adminPassword = "P@ssword1",
    [string] $registryUsername = "",
    [string] $registryPassword = "",
    [string] $licenseFileUri = "",
    [string] $enableTaskScheduler = "Default",
    [string] $workshopFilesUrl = "",
    [string] $finalSetupScriptUrl = "",
    [string] $style = "devpreview",
    [string] $RunWindowsUpdate = "No",
    [string] $nchBranch = ""
)
function Get-VariableDeclaration([string]$name) {
    $var = Get-Variable -Name $name
    if ($var) {
        ('$' + $var.Name + ' = "' + $var.Value + '"')
    }
    else {
        ""
    }
}

function Log([string]$line, [string]$color = "Gray") {
    ("<font color=""$color"">" + [DateTime]::Now.ToString([System.Globalization.DateTimeFormatInfo]::CurrentInfo.ShortTimePattern.replace(":mm", ":mm:ss")) + " $line</font>") | Add-Content -Path "c:\demo\status.txt"
}

function Get-WebFile([string]$sourceUrl, [string]$destinationFile) {
    Log "Downloading $destinationFile"
    Remove-Item -Path $destinationFile -Force -ErrorAction Ignore
    (New-Object System.Net.WebClient).DownloadFile($sourceUrl, $destinationFile)
}
Log -color Green "MY Starting initialization. Public Dns Name: $publicDnsName. Host Name: $hostName"

if ($publicDnsName -eq "") {
    $publicDnsName = $hostname
}

$ComputerInfo = Get-ComputerInfo
$WindowsInstallationType = $ComputerInfo.WindowsInstallationType
$WindowsProductName = $ComputerInfo.WindowsProductName

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12

$settingsScript = "c:\demo\settings.ps1"
if (Test-Path $settingsScript) {
    . "$settingsScript"
}
else {
    New-Item -Path "c:\myfolder" -ItemType Directory -ErrorAction Ignore | Out-Null
    New-Item -Path "C:\DEMO" -ItemType Directory -ErrorAction Ignore | Out-Null
    Get-VariableDeclaration -name "templateLink" | Set-Content $settingsScript
    Get-VariableDeclaration -name "hostName" | Add-Content $settingsScript
    Get-VariableDeclaration -name "RemoteDesktopAccess" | Add-Content $settingsScript
    Get-VariableDeclaration -name "vmAdminUsername" | Add-Content $settingsScript
    Get-VariableDeclaration -name "adminPassword" | Add-Content $settingsScript
    Get-VariableDeclaration -name "registryUsername" | Add-Content $settingsScript
    Get-VariableDeclaration -name "registryPassword" | Add-Content $settingsScript
    Get-VariableDeclaration -name "licenseFileUri" | Add-Content $settingsScript
    Get-VariableDeclaration -name "enableTaskScheduler" | Add-Content $settingsScript
    Get-VariableDeclaration -name "workshopFilesUrl" | Add-Content $settingsScript
    Get-VariableDeclaration -name "style" | Add-Content $settingsScript
    Get-VariableDeclaration -name "RunWindowsUpdate" | Add-Content $settingsScript

    $passwordKey = New-Object Byte[] 16
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($passwordKey)
    ('$passwordKey = [byte[]]@(' + "$passwordKey".Replace(" ", ",") + ')') | Add-Content $settingsScript

    $securePassword = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $encPassword = ConvertFrom-SecureString -SecureString $securePassword -Key $passwordKey
    ('$adminPassword = "' + $encPassword + '"') | Add-Content $settingsScript
}

if (Test-Path -Path "c:\DEMO\Status.txt" -PathType Leaf) {
    Log "VM already initialized."
    exit
}

Set-Content "c:\DEMO\RemoteDesktopAccess.txt" -Value $RemoteDesktopAccess

Set-ExecutionPolicy -ExecutionPolicy unrestricted -Force

Log -color Green "Starting initialization. Public Dns Name: $publicDnsName. Host Name: $hostName"
Log "Running $WindowsProductName"
Log "Initialize, user: $env:USERNAME"
Log "TemplateLink: $templateLink"
$scriptPath = $templateLink.SubString(0, $templateLink.LastIndexOf('/') + 1)

New-Item -Path "C:\DOWNLOAD" -ItemType Directory -ErrorAction Ignore | Out-Null

if (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction Ignore)) {
    Log "Installing NuGet Package Provider"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -WarningAction Ignore | Out-Null
}

Log "Installing Internet Information Server (this might take a few minutes)"
if ($WindowsInstallationType -eq "Server") {
    Add-WindowsFeature Web-Server, web-Asp-Net45
}
else {
    Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServer, IIS-ASPNET45 -All -NoRestart | Out-Null
}

Remove-Item -Path "C:\inetpub\wwwroot\iisstart.*" -Force
Get-WebFile -sourceUrl "${scriptPath}Default.aspx"            -destinationFile "C:\inetpub\wwwroot\default.aspx"
Get-WebFile -sourceUrl "${scriptPath}status.aspx"             -destinationFile "C:\inetpub\wwwroot\status.aspx"
Get-WebFile -sourceUrl "${scriptPath}line.png"                -destinationFile "C:\inetpub\wwwroot\line.png"
Get-WebFile -sourceUrl "${scriptPath}Microsoft.png"           -destinationFile "C:\inetpub\wwwroot\Microsoft.png"
Get-WebFile -sourceUrl "${scriptPath}web.config"              -destinationFile "C:\inetpub\wwwroot\web.config"

$title = 'Dynamics Container Host'
[System.IO.File]::WriteAllText("C:\inetpub\wwwroot\title.txt", $title)
# TODO: temp fix
# [System.IO.File]::WriteAllText("C:\inetpub\wwwroot\hostname.txt", $publicDnsName)
[System.IO.File]::WriteAllText("C:\inetpub\wwwroot\hostname.txt", $hostName)

# TODO: temp fix
# if ("$RemoteDesktopAccess" -ne "") {
#     Log "Creating Connect.rdp"
#     "full address:s:${publicDnsName}:3389
# prompt for credentials:i:1
# username:s:$vmAdminUsername" | Set-Content "c:\inetpub\wwwroot\Connect.rdp"
# }
if ("$RemoteDesktopAccess" -ne "") {
    Log "Creating Connect.rdp"
    "full address:s:${hostName}:3389
prompt for credentials:i:1
username:s:$vmAdminUsername" | Set-Content "c:\inetpub\wwwroot\Connect.rdp"
}
if ($WindowsInstallationType -eq "Server") {
    Log "Turning off IE Enhanced Security Configuration"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 | Out-Null
    Log "Disable Internet Explorer First Run Welcome Screen Pop Up"

    if (!(Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main\" -Name "DisableFirstRunCustomize")) {
        New-Item -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main\" -Force | Out-Null
    }
    Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main" -Name "DisableFirstRunCustomize" -Value 2 | Out-Null
}

$setupDesktopScript = "c:\demo\SetupDesktop.ps1"
$setupStartScript = "c:\demo\SetupStart.ps1"
$setupVmScript = "c:\demo\SetupVm.ps1"
$additionalInstall = "c:\demo\additional-install.ps1"
$CreateAzureDevOpsAgent = "c:\demo\CreateAzureDevOpsAgent.ps1"

# TODO: not used?
# $setupAadScript = "c:\demo\SetupAAD.ps1"

Log "Downloading files"
Get-WebFile -sourceUrl "${scriptPath}SetupWebClient.ps1"    -destinationFile "c:\myfolder\SetupWebClient.ps1"

Get-WebFile -sourceUrl "${scriptPath}SetupDesktop.ps1"      -destinationFile $setupDesktopScript
# TODO: not used?
# Get-WebFile -sourceUrl "${scriptPath}SetupAAD.ps1"          -destinationFile $setupAadScript
Get-WebFile -sourceUrl "${scriptPath}SetupVm.ps1"           -destinationFile $setupVmScript
Get-WebFile -sourceUrl "${scriptPath}SetupStart.ps1"        -destinationFile $setupStartScript
Get-WebFile -sourceUrl "${scriptPath}additional-install.ps1"        -destinationFile $additionalInstall
# Get-WebFile -sourceUrl "${scriptPath}RestartContainers.ps1" -destinationFile "c:\demo\restartContainers.ps1"
Get-WebFile -sourceUrl "${scriptPath}CreateAzureDevOpsAgent.ps1"      -destinationFile $CreateAzureDevOpsAgent

if ($finalSetupScriptUrl) {
    $finalSetupScript = "c:\demo\FinalSetupScript.ps1"
    Get-WebFile -sourceUrl $finalSetupScriptUrl -destinationFile $finalSetupScript
}

if ($workshopFilesUrl -ne "") {
    $workshopFilesFolder = "c:\WorkshopFiles"
    $workshopFilesFile = "C:\DOWNLOAD\WorkshopFiles.zip"
    New-Item -Path $workshopFilesFolder -ItemType Directory -ErrorAction Ignore | Out-Null
    Get-WebFile -sourceUrl $workshopFilesUrl -destinationFile $workshopFilesFile
    Log "Unpacking Workshop Files to $WorkshopFilesFolder"
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($workshopFilesFile, $workshopFilesFolder)
}


if ($nchBranch) {
    if ($nchBranch -notlike "https://*") {
        $nchBranch = "https://github.com/Microsoft/navcontainerhelper/archive/$($nchBranch).zip"
    }
    Log "Using Nav Container Helper from $nchBranch"
    Get-WebFile -sourceUrl $nchBranch -destinationFile "c:\demo\navcontainerhelper.zip"
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory("c:\demo\navcontainerhelper.zip", "c:\demo")
    $module = Get-Item -Path "C:\demo\*\NavContainerHelper.psm1"
    Log "Loading NavContainerHelper from $($module.FullName)"
    Import-Module $module.FullName -DisableNameChecking
}
else {
    Log "Installing Latest Nav Container Helper from PowerShell Gallery"
    Install-Module -Name navcontainerhelper -Force
    Import-Module -Name navcontainerhelper -DisableNameChecking
    Log ("Using Nav Container Helper version " + (get-module NavContainerHelper).Version.ToString())
}

if ($WindowsInstallationType -eq "Server") {
    if (!(Test-Path -Path "C:\Program Files\Docker\docker.exe" -PathType Leaf)) {
        Log "Installing Docker"
        Install-module DockerMsftProvider -Force
        Install-Package -Name docker -ProviderName DockerMsftProvider -Force
    }
}
else {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V, Containers -All -NoRestart | Out-Null
}

Log "Creating task before restart"
$startupAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy UnRestricted -File $setupStartScript"
$startupTrigger = New-ScheduledTaskTrigger -AtStartup
$startupTrigger.Delay = "PT1M"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd
Register-ScheduledTask -TaskName "SetupStart" `
    -Action $startupAction `
    -Trigger $startupTrigger `
    -Settings $settings `
    -RunLevel "Highest" `
    -User "NT AUTHORITY\SYSTEM" | Out-Null

Log "Restarting computer and start Installation tasks"
Shutdown -r -t 60
