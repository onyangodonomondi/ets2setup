# ===================================================================
# ETS2 Server Complete Setup Script for Windows
# ===================================================================
# Description: Automates the full installation and configuration of an Euro Truck Simulator 2 dedicated server on Windows
# Author: Unknown
# Usage: powershell -ExecutionPolicy Bypass -File setup_ETS2_server.ps1 [STEAM_TOKEN]
# Version: 2.0.0
# ===================================================================

# Script parameters
param (
    [string]$SERVER_TOKEN = "18D10BF61B4AE256FA9189A649AC24F1"
)

# ===================================================================
# ERROR HANDLING AND ROBUSTNESS
# ===================================================================
# Exit codes
$E_GENERAL = 1      # General error
$E_DEPENDENCY = 2   # Missing dependency
$E_NETWORK = 3      # Network issue
$E_PERMISSION = 4   # Permission issue
$E_INVALID = 5      # Invalid input
$E_DISK = 6         # Disk space issue

# Script version
$SCRIPT_VERSION = "2.0.0"

# Log file
$ROOT_DIR = Get-Location
$LOG_FILE = "$ROOT_DIR\ets2_setup.log"
$SERVER_DIR = "$ROOT_DIR\ets2server"
$BACKUP_DIR = "$ROOT_DIR\backups"

# ===================================================================
# HELPER FUNCTIONS
# ===================================================================
# Logging function
function Log-Message {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp: $message" | Tee-Object -Append -FilePath $LOG_FILE
}

# Info message
function Write-InfoMessage {
    param([string]$message)
    Write-Host -ForegroundColor Cyan "[INFO] $message"
    Log-Message "INFO: $message"
}

# Success message
function Write-SuccessMessage {
    param([string]$message)
    Write-Host -ForegroundColor Green "[SUCCESS] $message"
    Log-Message "SUCCESS: $message"
}

# Warning message
function Write-WarningMessage {
    param([string]$message)
    Write-Host -ForegroundColor Yellow "[WARNING] $message"
    Log-Message "WARNING: $message"
}

# Error message
function Write-ErrorMessage {
    param(
        [string]$message,
        [int]$exitCode = $E_GENERAL
    )
    Write-Host -ForegroundColor Red "[ERROR] $message"
    Log-Message "ERROR: $message"
    if ($exitCode -ne 0) {
        exit $exitCode
    }
}

# Check if a command exists
function Test-Command {
    param([string]$command)
    
    try {
        if (Get-Command $command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
    
    return $false
}

# Check disk space
function Test-DiskSpace {
    param(
        [string]$path,
        [int]$minSpaceMB
    )
    
    try {
        $drive = Split-Path -Qualifier (Resolve-Path $path).Path
        $freeSpace = [math]::Round((Get-PSDrive $drive.Replace(':', '')).Free / 1MB)
        
        if ($freeSpace -lt $minSpaceMB) {
            Write-ErrorMessage "Not enough disk space. Required: $minSpaceMB MB, Available: $freeSpace MB" $E_DISK
            return $false
        }
        
        return $true
    }
    catch {
        Write-WarningMessage "Could not check disk space: $_"
        return $true # Assume there's enough space
    }
}

# Download file with retry
function Download-FileWithRetry {
    param(
        [string]$url,
        [string]$output
    )
    
    $maxRetries = 3
    $retry = 0
    $success = $false
    
    while ($retry -lt $maxRetries -and -not $success) {
        try {
            Write-InfoMessage "Downloading from $url (attempt $(($retry + 1))/$maxRetries)"
            Invoke-WebRequest -Uri $url -OutFile $output
            $success = $true
            Write-SuccessMessage "Download completed successfully: $output"
        }
        catch {
            $retry++
            if ($retry -lt $maxRetries) {
                Write-WarningMessage "Download failed. Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
            else {
                Write-ErrorMessage "Failed to download after $maxRetries attempts: $_" $E_NETWORK
                return $false
            }
        }
    }
    
    return $success
}

# Create directory if it doesn't exist
function Create-DirectoryIfNotExists {
    param([string]$path)
    
    if (-not (Test-Path $path)) {
        try {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-SuccessMessage "Created directory: $path"
        }
        catch {
            Write-ErrorMessage "Failed to create directory: $path - $_" $E_PERMISSION
            return $false
        }
    }
    else {
        Write-InfoMessage "Directory already exists: $path"
    }
    
    return $true
}

# Test network connectivity
function Test-NetworkConnectivity {
    $host = "download.eurotrucksimulator2.com"
    Write-InfoMessage "Testing network connectivity to $host..."
    
    try {
        $testConnection = Test-Connection -ComputerName $host -Count 1 -Quiet
        if ($testConnection) {
            Write-SuccessMessage "Network connectivity confirmed."
            return $true
        }
        else {
            Write-WarningMessage "Cannot reach $host. Trying alternative method..."
            try {
                $request = [System.Net.WebRequest]::Create("https://$host")
                $response = $request.GetResponse()
                $response.Close()
                Write-SuccessMessage "Network connectivity confirmed (alternate method)."
                return $true
            }
            catch {
                Write-ErrorMessage "Network connectivity test failed. Check your internet connection: $_" $E_NETWORK
                return $false
            }
        }
    }
    catch {
        Write-ErrorMessage "Network connectivity test failed. Check your internet connection: $_" $E_NETWORK
        return $false
    }
}

# Create a backup
function Create-Backup {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$BACKUP_DIR\ets2_server_backup_$timestamp.zip"
    
    Write-InfoMessage "Creating server backup..."
    
    # Create backup directory if it doesn't exist
    Create-DirectoryIfNotExists $BACKUP_DIR
    
    # Create a list of files to backup
    $backupItems = @(
        "$SERVER_DIR\server_config.sii",
        "$SERVER_DIR\server_packages.sii",
        "$SERVER_DIR\server_packages.dat"
    )
    
    # Check if files exist
    $filesToBackup = @()
    foreach ($item in $backupItems) {
        if (Test-Path $item) {
            $filesToBackup += $item
        }
    }
    
    if ($filesToBackup.Count -eq 0) {
        Write-WarningMessage "No files found to backup."
        return $false
    }
    
    # Create the backup
    try {
        Compress-Archive -Path $filesToBackup -DestinationPath $backupFile -Force
        Write-SuccessMessage "Backup created: $backupFile"
        
        # Cleanup old backups (keep last 5)
        $oldBackups = Get-ChildItem -Path "$BACKUP_DIR\ets2_server_backup_*.zip" |
                     Sort-Object -Property LastWriteTime -Descending |
                     Select-Object -Skip 5
        
        if ($oldBackups) {
            Write-InfoMessage "Cleaning up old backups..."
            foreach ($backup in $oldBackups) {
                Remove-Item $backup.FullName -Force
            }
        }
        
        return $true
    }
    catch {
        Write-WarningMessage "Failed to create backup: $_"
        return $false
    }
}

# ===================================================================
# MAIN SCRIPT
# ===================================================================
# Initialize log file
New-Item -Path $LOG_FILE -ItemType File -Force | Out-Null
Log-Message "Starting ETS2 server setup"
Write-InfoMessage "Beginning ETS2 server setup process (v$SCRIPT_VERSION)"

# Display script header
Write-Host @"
====================================================================
 🚚 ETS2 SERVER SETUP SCRIPT v$SCRIPT_VERSION (WINDOWS VERSION)
====================================================================
This script will install and configure an Euro Truck Simulator 2 
dedicated server on your Windows system.

"@

# Check disk space
if (-not (Test-DiskSpace -path $ROOT_DIR -minSpaceMB 1024)) {
    exit $E_DISK
}

# Test network connectivity
if (-not (Test-NetworkConnectivity)) {
    exit $E_NETWORK
}

# Check for required tools
Write-InfoMessage "Checking for required tools..."
if (-not (Test-Command "Compress-Archive")) {
    Write-WarningMessage "PowerShell 5.0 or higher is required for Compress-Archive cmdlet."
}

# Create directory structure
Write-InfoMessage "Setting up directory structure..."
Create-DirectoryIfNotExists $SERVER_DIR
Create-DirectoryIfNotExists "$ROOT_DIR\AppData\Local\Euro Truck Simulator 2"
Create-DirectoryIfNotExists $BACKUP_DIR

# Download ETS2 dedicated server (if not already present)
$serverPackFile = "$ROOT_DIR\ets2_server_pack.zip"
if (-not (Test-Path $serverPackFile)) {
    Write-InfoMessage "Downloading server files. This may take a while..."
    $serverPackUrl = "https://download.eurotrucksimulator2.com/server_pack_1.47.zip"
    if (-not (Download-FileWithRetry -url $serverPackUrl -output $serverPackFile)) {
        exit $E_NETWORK
    }
}
else {
    Write-InfoMessage "Server pack already downloaded. Skipping download."
    
    # Verify the zip file
    try {
        $testZip = Test-Path $serverPackFile -PathType Leaf
        if (-not $testZip) {
            Write-WarningMessage "The existing ZIP file appears to be invalid. Re-downloading..."
            Move-Item -Path $serverPackFile -Destination "$serverPackFile.bak" -Force
            if (-not (Download-FileWithRetry -url "https://download.eurotrucksimulator2.com/server_pack_1.47.zip" -output $serverPackFile)) {
                exit $E_NETWORK
            }
        }
    }
    catch {
        Write-WarningMessage "Error checking ZIP file: $_. Re-downloading..."
        if (-not (Download-FileWithRetry -url "https://download.eurotrucksimulator2.com/server_pack_1.47.zip" -output $serverPackFile)) {
            exit $E_NETWORK
        }
    }
}

# Extract server files
Write-InfoMessage "Extracting server files..."
try {
    Expand-Archive -Path $serverPackFile -DestinationPath $SERVER_DIR -Force
    Write-SuccessMessage "Server files extracted successfully."
}
catch {
    Write-ErrorMessage "Failed to extract server files: $_" $E_GENERAL
    exit $E_GENERAL
}

# Create server configuration
Write-InfoMessage "Creating server configuration files..."

$SERVER_NAME = "Windows ETS2 Server"
$SERVER_DESC = "Join our friendly Windows-based trucking community!"
$WELCOME_MSG = "Welcome to Windows ETS2 Trucking Server! Enjoy your journey."
$MAX_PLAYERS = 8
$SERVER_PORT = 27015
$QUERY_PORT = 27016

# Create backup of existing config if it exists
if (Test-Path "$SERVER_DIR\server_config.sii") {
    Write-InfoMessage "Backing up existing server configuration..."
    Copy-Item -Path "$SERVER_DIR\server_config.sii" -Destination "$SERVER_DIR\server_config.sii.bak" -Force
}

# Create the server configuration file
$serverConfigContent = @"
SiiNunit
{
server_config: _nameless.server.config
{
  // Basic Server Info
  lobby_name: "$SERVER_NAME"  // Visible server name
  description: "$SERVER_DESC"  // Server description
  welcome_message: "$WELCOME_MSG"  // Shown on player connect

  // Security & Access
  password: ""                          // Set a password for private access
  friends_only: false                   // Allow public connections
  show_server: true                     // Advertise publicly in server list

  // Player Limits
  max_players: $MAX_PLAYERS            // Number of players
  max_vehicles_total: 100              // Total vehicles
  max_ai_vehicles_player: 50           // AI vehicles per player
  max_ai_vehicles_player_spawn: 50     // AI vehicles spawn limit

  // Network Configuration
  connection_virtual_port: 100         // Virtual connection port
  query_virtual_port: 101              // Virtual query port
  connection_dedicated_port: $SERVER_PORT     // Default TCP/UDP
  query_dedicated_port: $QUERY_PORT          // Match firewall rules

  // Server Token
  server_logon_token: "$SERVER_TOKEN"  // Required for public listing
  roads_data_file_name: "$SERVER_DIR\server_packages.dat"

  // Gameplay Rules
  player_damage: true                  // Enable vehicle damage
  traffic: true                        // Show AI traffic
  hide_in_company: false               // Show trucks in company areas
  hide_colliding: true                 // Hide colliding vehicles
  force_speed_limiter: false           // Let players disable speed limiter
  mods_optioning: false                // Allow mods
  timezones: 0                         // 0=Real time, 1=Sync with host

  // Visibility Settings
  service_no_collision: false          // Allow collisions at service stations
  in_menu_ghosting: false              // Ghost mode when in menu
  name_tags: true                      // Show player names above trucks
  
  // Moderation
  moderator_list: 0                    // No moderators defined
}
}
"@

Set-Content -Path "$SERVER_DIR\server_config.sii" -Value $serverConfigContent
Write-SuccessMessage "Server configuration created successfully."

# Create the server_packages.sii file
$serverPackagesContent = @"
SiiNunit
{
server_packages_info : _nameless.1ae.f18a.b110 {
 version: 1
 dlc_essential_list: 0
 dlc_non_essential_list: 0
 mod_list: 0
 map_name: "/map/europe.mbd"
 map_dimensions: (-24576000, -16384000, 20480000, 22528000)
 roads_data_file_name: "$SERVER_DIR\server_packages.dat"
 time_stamp: $([int][double]::Parse((Get-Date -UFormat %s)))
 time_compression: 15.560001
}
}
"@

Set-Content -Path "$SERVER_DIR\server_packages.sii" -Value $serverPackagesContent

# Create dummy server_packages.dat
try {
    $dummyFile = New-Item -Path "$SERVER_DIR\server_packages.dat" -ItemType File -Force
    $fs = $dummyFile.OpenWrite()
    $fs.SetLength(10KB)
    $fs.Close()
    Write-SuccessMessage "Server packages files created successfully."
}
catch {
    Write-ErrorMessage "Failed to create server_packages.dat: $_" $E_GENERAL
    exit $E_GENERAL
}

# Copy server packages to required locations
Write-InfoMessage "Copying server packages to required locations..."

$locations = @(
    "$ROOT_DIR\AppData\Local\Euro Truck Simulator 2",
    "$SERVER_DIR\bin\win_x64"
)

foreach ($location in $locations) {
    Create-DirectoryIfNotExists $location
    try {
        Copy-Item -Path "$SERVER_DIR\server_packages.sii" -Destination $location -Force
        Copy-Item -Path "$SERVER_DIR\server_packages.dat" -Destination $location -Force
        Write-SuccessMessage "Copied server packages to $location"
    }
    catch {
        Write-WarningMessage "Failed to copy server packages to $location: $_"
    }
}

# Create start batch file
Write-InfoMessage "Creating server management scripts..."

$startScriptContent = @"
@echo off
:: ETS2 Server Start Script for Windows
:: Description: Starts the ETS2 dedicated server
title ETS2 Server

:: Set working directory to the server directory
cd /d %~dp0\ets2server

:: Log file for server output
set LOG_FILE=..\ets2_server.log

:: Create empty log file
echo Starting ETS2 server at %date% %time% > %LOG_FILE%

:: Check if server is already running
tasklist /FI "IMAGENAME eq eurotrucks2_server.exe" | find "eurotrucks2_server.exe" > nul
if not errorlevel 1 (
    echo WARNING: ETS2 server is already running! >> %LOG_FILE%
    echo WARNING: ETS2 server is already running!
    choice /C YN /M "Do you want to kill the existing server and start a new one?"
    if errorlevel 2 goto :eof
    taskkill /F /IM eurotrucks2_server.exe
    timeout /t 2 /nobreak > nul
)

:: Remove existing PID file
if exist ..\ets2_server.pid del ..\ets2_server.pid

:: Copy server packages files to required locations
echo Copying server packages files to required locations... >> %LOG_FILE%
xcopy /y server_packages.* bin\win_x64\ > nul

:: Change to the binary directory
cd bin\win_x64
echo Executing from directory: %CD% >> %LOG_FILE%
echo Command: eurotrucks2_server.exe >> %LOG_FILE%

:: Start the server in the background
echo Starting server... >> %LOG_FILE%
echo Starting server...
start /b eurotrucks2_server.exe >> %LOG_FILE% 2>&1

:: Get the PID of the server process and save it
for /f "tokens=2" %%P in ('tasklist /FI "IMAGENAME eq eurotrucks2_server.exe" /FO LIST ^| find "PID:"') do (
    echo %%P > ..\..\..\ets2_server.pid
    echo Server started with PID: %%P >> %LOG_FILE%
    echo Server started with PID: %%P
)

:: Check if the server is running after 2 seconds
timeout /t 2 /nobreak > nul
tasklist /FI "IMAGENAME eq eurotrucks2_server.exe" | find "eurotrucks2_server.exe" > nul
if errorlevel 1 (
    echo WARNING: Server process has already terminated! Check logs for errors. >> %LOG_FILE%
    echo WARNING: Server process has already terminated! Check logs for errors.
) else (
    echo Server process is running. >> %LOG_FILE%
    echo Server is now running.
)

echo.
echo ======================================================================
echo ETS2 Server has been started!
echo - To check server logs: type "ets2_server.log"
echo - To stop the server: run stop_ets2_server.bat
echo ======================================================================
echo.
"@

Set-Content -Path "$ROOT_DIR\start_ets2_server.bat" -Value $startScriptContent

# Create stop batch file
$stopScriptContent = @"
@echo off
:: ETS2 Server Stop Script for Windows
:: Description: Stops the ETS2 dedicated server
title ETS2 Server Stop

:: Log file
set LOG_FILE=%~dp0\ets2_stop.log
echo %date% %time%: Stopping ETS2 server > %LOG_FILE%

:: Check for PID file
set PID_FILE=%~dp0\ets2_server.pid
if exist %PID_FILE% (
    set /p PID=<%PID_FILE%
    echo Found PID file with PID: %PID% >> %LOG_FILE%
    
    :: Check if process is still running
    tasklist /FI "PID eq %PID%" | find "%PID%" > nul
    if not errorlevel 1 (
        echo Stopping ETS2 server (PID: %PID%)...
        echo Stopping ETS2 server (PID: %PID%)... >> %LOG_FILE%
        taskkill /PID %PID%
        
        :: Wait for process to terminate
        set count=0
        :WAIT_LOOP
        if %count% LSS 10 (
            tasklist /FI "PID eq %PID%" | find "%PID%" > nul
            if not errorlevel 1 (
                echo Waiting for server to shut down...
                timeout /t 2 /nobreak > nul
                set /a count+=1
                goto WAIT_LOOP
            )
        )
        
        :: Force kill if still running
        tasklist /FI "PID eq %PID%" | find "%PID%" > nul
        if not errorlevel 1 (
            echo Server not responding. Force stopping...
            echo Server not responding. Force stopping... >> %LOG_FILE%
            taskkill /F /PID %PID%
        )
        
        echo ETS2 server stopped.
    ) else (
        echo PID %PID% no longer exists. Cleaning up PID file.
        echo PID %PID% no longer exists. Cleaning up PID file. >> %LOG_FILE%
    )
    
    :: Remove PID file
    del %PID_FILE%
) else (
    echo No PID file found. Trying to find the process.
    echo No PID file found. Trying to find the process. >> %LOG_FILE%
    
    :: Try to find any eurotrucks2_server process
    tasklist /FI "IMAGENAME eq eurotrucks2_server.exe" | find "eurotrucks2_server.exe" > nul
    if not errorlevel 1 (
        echo Found server process. Stopping...
        echo Found server process. Stopping... >> %LOG_FILE%
        taskkill /F /IM eurotrucks2_server.exe
        echo ETS2 server stopped.
    ) else (
        echo No ETS2 server process found.
        echo No ETS2 server process found. >> %LOG_FILE%
    )
)

echo Stop operation completed at %date% %time% >> %LOG_FILE%
"@

Set-Content -Path "$ROOT_DIR\stop_ets2_server.bat" -Value $stopScriptContent

# Create restart batch file
$restartScriptContent = @"
@echo off
:: ETS2 Server Restart Script for Windows
:: Description: Restarts the ETS2 dedicated server
title ETS2 Server Restart

echo Restarting ETS2 server...

:: Get the directory of this script
set SCRIPT_DIR=%~dp0

:: Stop the server if it's running
call %SCRIPT_DIR%\stop_ets2_server.bat

:: Wait a moment before starting again
timeout /t 5 /nobreak > nul

:: Start the server
call %SCRIPT_DIR%\start_ets2_server.bat

echo ETS2 server restart complete.
"@

Set-Content -Path "$ROOT_DIR\restart_ets2_server.bat" -Value $restartScriptContent

# Open Windows Firewall ports
Write-InfoMessage "Configuring Windows Firewall..."

try {
    # Check if firewall rules already exist
    $existingRules = (Get-NetFirewallRule -DisplayName "ETS2 Server*" -ErrorAction SilentlyContinue)
    
    if ($existingRules) {
        Write-InfoMessage "Firewall rules for ETS2 Server already exist."
    }
    else {
        # Create firewall rules
        New-NetFirewallRule -DisplayName "ETS2 Server TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $SERVER_PORT,$QUERY_PORT | Out-Null
        New-NetFirewallRule -DisplayName "ETS2 Server UDP" -Direction Inbound -Action Allow -Protocol UDP -LocalPort $SERVER_PORT,$QUERY_PORT | Out-Null
        Write-SuccessMessage "Firewall rules created successfully."
    }
}
catch {
    Write-WarningMessage "Failed to configure Windows Firewall: $_. You may need to open ports manually."
}

# Create an initial backup
Write-InfoMessage "Creating initial backup..."
Create-Backup

# Display final messages
Write-SuccessMessage "ETS2 server setup completed successfully!"

Write-Host @"

======================================================================
 🚚 ETS2 SERVER SETUP COMPLETED SUCCESSFULLY!
======================================================================

Server information:
- Server name: $SERVER_NAME
- Maximum players: $MAX_PLAYERS
- Server port: $SERVER_PORT
- Query port: $QUERY_PORT

Server management:
- Start:    start_ets2_server.bat
- Stop:     stop_ets2_server.bat
- Restart:  restart_ets2_server.bat

Server files:
- Main config:     $SERVER_DIR\server_config.sii
- Packages config: $SERVER_DIR\server_packages.sii
- Executable:      $SERVER_DIR\bin\win_x64\eurotrucks2_server.exe

Log files:
- Setup log:   $LOG_FILE
- Server log:  $ROOT_DIR\ets2_server.log

Backup:
- Backup directory: $BACKUP_DIR

IMPORTANT: For a fully functioning server, you should replace the 
server_packages files with ones exported from your desktop game client.

======================================================================

"@
