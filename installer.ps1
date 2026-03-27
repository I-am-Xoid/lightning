
cls
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

param(
    [string]$DownloadLink, # Overwrites the download link (give a direct link)
    [string]$PluginName # Overwrites the plugin name
)

## Configure this
$Host.UI.RawUI.WindowTitle = "LIGHTNING INSTALLER | Made by @xoid.py"
$name = "Lightning" # automatic first letter uppercase included
$link = "https://github.com/I-am-Xoid/lightning/releases/latest/download/src.zip"
$milleniumTimer = 5 # in seconds for auto-installation

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Hidden defines
$upperName = $name.Substring(0, 1).ToUpper() + $name.Substring(1).ToLower()
if ( $DownloadLink ) {
    $link = $DownloadLink
}
if ( $PluginName ) {
    $name = $PluginName
}


#### Logging defines ####
function Log {
    param ([string]$Type, [string]$Message, [boolean]$NoNewline = $false)

    $Type = $Type.ToUpper()
    switch ($Type) {
        "OK" { $foreground = "Green" }
        "INFO" { $foreground = "Cyan" }
        "ERR" { $foreground = "Red" }
        "WARN" { $foreground = "Yellow" }
        "LOG" { $foreground = "Magenta" }
        "AUX" { $foreground = "DarkGray" }
        default { $foreground = "White" }
    }

    $date = Get-Date -Format "HH:mm:ss"
    $prefix = if ($NoNewline) { "`r[$date] " } else { "[$date] " }
    Write-Host $prefix -ForegroundColor "Cyan" -NoNewline

    Write-Host [$Type] $Message -ForegroundColor $foreground -NoNewline:$NoNewline
}


# To hide IEX blue box thing
$ProgressPreference = 'SilentlyContinue'

$localPath = Join-Path $env:LOCALAPPDATA "steam"
$steamRegPath = 'HKCU:\Software\Valve\Steam'
$steamToolsRegPath = 'HKCU:\Software\Valve\Steamtools'
# $steamPath is already defined above, will be populated by the Steam path detection logic

function Remove-ItemIfExists($path) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
    }
}

function ForceStopProcess($processName) {
    Get-Process $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Get-Process $processName -ErrorAction SilentlyContinue) {
        Start-Process cmd -ArgumentList "/c taskkill /f /im $processName.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
}

function CheckAndPromptProcess($processName, $message) {
    while (Get-Process $processName -ErrorAction SilentlyContinue) {
        Write-Host $message -ForegroundColor Red
        Start-Sleep 1.5
    }
}

$filePathToDelete = Join-Path $env:USERPROFILE "get.ps1"
Remove-ItemIfExists $filePathToDelete

ForceStopProcess "steam"
if (Get-Process "steam" -ErrorAction SilentlyContinue) {
    CheckAndPromptProcess "Steam" "[Please exit Steam client first]"
}

if (Test-Path $steamRegPath) {
    $properties = Get-ItemProperty -Path $steamRegPath -ErrorAction SilentlyContinue
    if ($properties -and 'SteamPath' -in $properties.PSObject.Properties.Name) {
        $steamPath = $properties.SteamPath
    }
}
if ([string]::IsNullOrWhiteSpace($steamPath)) {
    Write-Host "Official Steam client is not installed on your computer. Please install it and try again." -ForegroundColor Red
    Start-Sleep 10
    exit
}

if (-not (Test-Path $steamPath -PathType Container)) {
    Write-Host "Official Steam client is not installed on your computer. Please install it and try again." -ForegroundColor Red
    Start-Sleep 10
    exit
}

#### Requirements part ####

# Steamtools check
function CheckSteamtools {
    $files = @( "dwmapi.dll", "xinput1_4.dll" )
    foreach($file in $files) {
        if (!( Test-Path (Join-Path $steamPath $file) )) {
            return $false
        }
    }

    return $true
}

if ( CheckSteamtools ) {
    Log "INFO" "Steamtools already installed"
}
else {
    Log "ERR" "Steamtools not found."
    Log "AUX" "Install it at your own risk! Close this script if you don't want to."
    Log "WARN" "Pressing any key will install steamtools (UI-less)."

    [void][System.Console]::ReadKey($true)
    Write-Host
    Log "WARN" "Installing Steamtools"

    # --- Start of PwStart (Steamtools specific parts) ---
    try {
        if (!$steamPath) {
            return
        }
        if (!(Test-Path $localPath)) {
            New-Item $localPath -ItemType directory -Force -ErrorAction SilentlyContinue
        }

        $steamCfgPath = Join-Path $steamPath "steam.cfg"
        Remove-ItemIfExists $steamCfgPath

        $steamBetaPath = Join-Path $steamPath "package\beta"
        Remove-ItemIfExists $steamBetaPath

        $catchPath = Join-Path $env:LOCALAPPDATA "Microsoft\Tencent"
        Remove-ItemIfExists $catchPath

        $hidPath = Join-Path $steamPath "xinput1_4.dll"
        $dwmapiPath = Join-Path $steamPath "dwmapi.dll"

        try { Add-MpPreference -ExclusionPath $hidPath -ErrorAction SilentlyContinue } catch {}

        $versionDllPath = Join-Path $steamPath "version.dll"
        Remove-ItemIfExists $versionDllPath

        $downloadHidDll = "http://update.aaasn.com/update"

        try {
            Invoke-RestMethod -Uri $downloadHidDll -OutFile $hidPath -ErrorAction Stop
        } catch {
            if (Test-Path $hidPath) {
                Move-Item -Path $hidPath -Destination "$hidPath.old" -Force -ErrorAction SilentlyContinue
                Invoke-RestMethod -Uri $downloadHidDll -OutFile $hidPath -ErrorAction SilentlyContinue
            }
        }

        $downloadDwmapi = "http://update.aaasn.com/dwmapi"
        try { Add-MpPreference -ExclusionPath $dwmapiPath -ErrorAction SilentlyContinue } catch {}
        try {
            Invoke-RestMethod -Uri $downloadDwmapi -OutFile $dwmapiPath -ErrorAction Stop
        } catch {
            if (Test-Path $dwmapiPath) {
                Move-Item -Path $dwmapiPath -Destination "$dwmapiPath.old" -Force -ErrorAction SilentlyContinue
                Invoke-RestMethod -Uri $downloadDwmapi -OutFile $dwmapiPath -ErrorAction SilentlyContinue
            }
        }

        if (!(Test-Path $steamToolsRegPath)) {
            New-Item -Path $steamToolsRegPath -Force | Out-Null
        }

        Remove-ItemProperty -Path $steamToolsRegPath -Name "ActivateUnlockMode" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $steamToolsRegPath -Name "AlwaysStayUnlocked" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $steamToolsRegPath -Name "notUnlockDepot" -ErrorAction SilentlyContinue

        Set-ItemProperty -Path $steamToolsRegPath -Name "iscdkey" -Value "false" -Type String

        Log "OK" "Steamtools installed"
    } catch {
        Log "ERR" "Steamtools installation failed: $($_.Exception.Message)"
    }
    # --- End of PwStart (Steamtools specific parts) ---
}

# Millenium check
$milleniumInstalling = $false
foreach ($file in @("millennium.dll", "python311.dll")) {
    if (!( Test-Path (Join-Path $steamPath $file) )) {
        
        # Ask confirmation to download
        Log "ERR" "Millenium not found, installation process will start in 5 seconds."
        Log "WARN" "Press any key to cancel the installation."
        
        for ($i = $milleniumTimer; $i -ge 0; $i--) {
            # Wheter a key was pressed
            if ([Console]::KeyAvailable) {
                Write-Host
                Log "ERR" "Installation cancelled by user."
                exit
            }

            Log "LOG" "Installing Millenium in $i second(s)... Press any key to cancel." $true
            Start-Sleep -Seconds 1
        }
        Write-Host



        Log "INFO" "Installing millenium"

        Invoke-Expression "& { $(Invoke-RestMethod 'https://clemdotla.github.io/millennium-installer-ps1/millennium.ps1') } -NoLog -DontStart -SteamPath '$steamPath'"

        Log "OK" "Millenium done installing"
        $milleniumInstalling = $true
        break
    }
}
if ($milleniumInstalling -eq $false) { Log "INFO" "Millenium already installed" }

#### Plugin part ####
# Ensuring \Steam\plugins
if (!( Test-Path (Join-Path $steamPath "plugins") )) {
    New-Item -Path (Join-Path $steamPath "plugins") -ItemType Directory *> $null
}


$Path = Join-Path $steamPath "plugins\$name" # Defaulting if no install found

# Checking for plugin named "$name"
foreach ($plugin in Get-ChildItem -Path (Join-Path $steamPath "plugins") -Directory) {
    $testpath = Join-Path $plugin.FullName "plugin.json"
    if (Test-Path $testpath) {
        $json = Get-Content $testpath -Raw | ConvertFrom-Json
        if ($json.name -eq $name) {
            Log "INFO" "Plugin already installed, updating it"
            $Path = $plugin.FullName # Replacing default path
            break
        }
    }
}

# Installation
$subPath = Join-Path $env:TEMP "$name.zip"

Log "LOG" "Downloading $name"
if ($DownloadLink) { Log "Aux" $($link) }
Invoke-WebRequest -Uri $link -OutFile $subPath *> $null
if ( !( Test-Path $subPath ) ) {
    Log "ERR" "Failed to download $name"
    exit
}
Log "LOG" "Unzipping $name"
try {      
    $zip = [System.IO.Compression.ZipFile]::OpenRead($subPath)
    foreach ($entry in $zip.Entries) {
        $entryName = $entry.FullName
        if ($entryName.StartsWith("src/", [System.StringComparison]::OrdinalIgnoreCase)) {
            $entryName = $entryName.Substring(4) # Remove "src/"
        }
        $destinationPath = Join-Path $Path $entryName
        
        if (-not $entry.FullName.EndsWith('/') -and -not $entry.FullName.EndsWith('\')) {
            $parentDir = Split-Path -Path $destinationPath -Parent
            if ($parentDir -and $parentDir.Trim() -ne '') {
                $pathParts = $parentDir -replace [regex]::Escape($steamPath), '' -split '[\\/]' | Where-Object { $_ }
                $currentPath = $Path
                
                foreach ($part in $pathParts) {
                    $currentPath = Join-Path $currentPath $part
                    if (Test-Path $currentPath) {
                        $item = Get-Item $currentPath
                        if (-not $item.PSIsContainer) {
                            Remove-Item $currentPath -Force
                        }
                    }
                }
                
                [System.IO.Directory]::CreateDirectory($parentDir) | Out-Null
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
            }
        }
    }
    
    $zip.Dispose()
}
catch {
    write-host "Error: $($_.Exception.Message)"
    if ($zip) { $zip.Dispose() }
    Log "ERR" "Custom extraction failed, trying fallback with temporary directory."

    $tempExtractPath = Join-Path $env:TEMP "$name-temp-extract"
    Remove-ItemIfExists $tempExtractPath
    New-Item -ItemType Directory -Path $tempExtractPath -Force | Out-Null

    try {
        Expand-Archive -Path $subPath -DestinationPath $tempExtractPath -Force
        
        $sourcePath = Join-Path $tempExtractPath "src"
        if (Test-Path $sourcePath) {
            Get-ChildItem -Path $sourcePath -Force | Move-Item -Destination $Path -Force
            Remove-Item $tempExtractPath -Recurse -Force
            Log "OK" "Fallback extraction successful and 'src' folder moved."
        } else {
            Log "WARN" "Fallback extraction completed, but 'src' folder not found in temporary location. Plugin might be incorrectly structured."
            # Clean up temp path anyway
            Remove-Item $tempExtractPath -Recurse -Force
        }
    } catch {
        Log "ERR" "Fallback extraction also failed: $($_.Exception.Message)"
        # Clean up temp path if it exists
        Remove-ItemIfExists $tempExtractPath
    }
}


if ( Test-Path $subPath ) {
    Remove-Item $subPath -ErrorAction SilentlyContinue
}

Log "OK" "$upperName installed"


# Removing beta
$betaPath = Join-Path $steamPath "package\beta"
if ( Test-Path $betaPath ) {
    Remove-Item $betaPath -Recurse -Force
}
# Removing potential x32 (kinda greedy but ppl got issues and was hard to fix without knowing it was the issue, ppl don't know what they run)
$cfgPath = Join-Path $steamPath "steam.cfg"
if ( Test-Path $cfgPath ) {
    Remove-Item $cfgPath -Recurse -Force
}
Remove-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Valve\Steam" -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "SteamCmdForceX86" -ErrorAction SilentlyContinue


# Toggling the plugin on (+turning off updateChecking to try fixing a bug where steam doesn't start)
$configPath = Join-Path $steamPath "ext/config.json"
if (-not (Test-Path $configPath)) {
    $config = @{
        plugins = @{
            enabledPlugins = @($name)
        }
        general = @{
            checkForMillenniumUpdates = $false
            theme = "space"
        }
    }
    New-Item -Path (Split-Path $configPath) -ItemType Directory -Force | Out-Null
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}
else {
    $config = (Get-Content $configPath -Raw -Encoding UTF8) | ConvertFrom-Json

    function _EnsureProperty {
        param($Object, $PropertyName, $DefaultValue)
        if (-not $Object.$PropertyName) {
            $Object | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $DefaultValue -Force
        }
    }

    _EnsureProperty $config "general" @{}
    _EnsureProperty $config "general.checkForMillenniumUpdates" $false
    $config.general.checkForMillenniumUpdates = $false
    _EnsureProperty $config "general.theme" "space"
    $config.general.theme = "space"

    _EnsureProperty $config "plugins" @{ enabledPlugins = @() }
    _EnsureProperty $config "plugins.enabledPlugins" @()
    
    $pluginsList = @($config.plugins.enabledPlugins)
    if ($pluginsList -notcontains $name) {
        $pluginsList += $name
        $config.plugins.enabledPlugins = $pluginsList
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}
Log "OK" "Plugin enabled"


# Result showing
Write-Host
if ($milleniumInstalling) { Log "WARN" "Steam startup will be longer, don't panic and don't touch anything in steam!" }


# Start with the "-clearbeta" argument
$exe = Join-Path $steamPath "steam.exe"
Start-Process $exe -ArgumentList "-clearbeta"

# The original st.ps1 had logic to close the installer window.
# I'll add this here to ensure the installer closes automatically after launching Steam.
# This logic is from the original st.ps1 PwStart function's end.
for ($i = 5; $i -ge 0; $i--) {
    Write-Host "`r[This window will close in $i seconds...]" -NoNewline
    Start-Sleep -Seconds 1
}

# This part tries to close the parent PowerShell process.
# I'll adapt it to directly exit the current script.
exit
