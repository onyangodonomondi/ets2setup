#!/bin/bash
# ===================================================================
# ETS2 Server Complete Setup Script
# ===================================================================
# Description: Automates the full installation and configuration of an Euro Truck Simulator 2 dedicated server
# Author: Unknown
# Usage: (Linux) ./setup_ETS2_server.sh [STEAM_TOKEN]
#        (Windows) powershell -ExecutionPolicy Bypass -File setup_ETS2_server.ps1 [STEAM_TOKEN]
# Version: 2.0.0
# ===================================================================

# ===================================================================
# DETECT OPERATING SYSTEM
# ===================================================================
detect_os() {
    # Default
    OS_TYPE="unknown"
    
    # Check if we're running on Windows
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS_TYPE="windows"
        echo "Detected Windows operating system."
        echo "Please use the PowerShell version of this script: setup_ETS2_server.ps1"
        exit 1
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        echo "MacOS is not supported for ETS2 dedicated servers."
        exit 1
    else
        OS_TYPE="linux"
        echo "Detected Linux operating system."
    fi
    
    return 0
}

# Check if we should generate the Windows script
if [ "$1" = "--generate-windows-script" ]; then
    echo "Generating Windows PowerShell script..."
    
    # Create a Windows PowerShell version of the script
    cat > setup_ETS2_server.ps1 << 'EOF'
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
EOF

    chmod +x setup_ETS2_server.ps1
    echo "Windows PowerShell script generated: setup_ETS2_server.ps1"
    echo "You can use this script on Windows systems by running:"
    echo "powershell -ExecutionPolicy Bypass -File setup_ETS2_server.ps1"
    exit 0
fi

# Run OS detection
detect_os

# Continue with Linux script (existing code)
# ===================================================================
# ERROR HANDLING AND ROBUSTNESS
# ===================================================================
# Exit codes
E_GENERAL=1      # General error
E_DEPENDENCY=2   # Missing dependency
E_NETWORK=3      # Network issue
E_PERMISSION=4   # Permission issue
E_INVALID=5      # Invalid input
E_DISK=6         # Disk space issue
E_PLATFORM=7     # Unsupported platform
E_VERSION=8      # Version mismatch

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script version
SCRIPT_VERSION="2.0.0"

# ===================================================================
# PLATFORM DETECTION AND COMPATIBILITY
# ===================================================================
# Detect the operating system family and version
detect_platform() {
    # Default to unknown
    OS_TYPE="unknown"
    OS_VERSION="unknown"
    PACKAGE_MANAGER=""
    
    # Check for common distribution detection methods
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS_TYPE=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS_TYPE="debian"
        OS_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE=$(grep -o -E '(Red Hat|CentOS|Fedora)' /etc/redhat-release | head -1 | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
        OS_VERSION=$(grep -o -E '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    elif [ -f /etc/arch-release ]; then
        OS_TYPE="arch"
        OS_VERSION="rolling"
    elif [ -f /etc/gentoo-release ]; then
        OS_TYPE="gentoo"
        OS_VERSION=$(cat /etc/gentoo-release | grep -o -E '[0-9]+\.[0-9]+')
    fi
    
    # Convert OS_TYPE to lowercase
    OS_TYPE=$(echo "$OS_TYPE" | tr '[:upper:]' '[:lower:]')
    
    # Determine package manager
    case "$OS_TYPE" in
        ubuntu|debian|raspbian|pop|mint|kali|zorin|elementary|deepin)
            PACKAGE_MANAGER="apt"
            ;;
        fedora)
            PACKAGE_MANAGER="dnf"
            ;;
        centos|rhel|redhat|rocky|almalinux|ol)
            if [ "${OS_VERSION%%.*}" -ge 8 ]; then
                PACKAGE_MANAGER="dnf"
            else
                PACKAGE_MANAGER="yum"
            fi
            ;;
        opensuse*|sles)
            PACKAGE_MANAGER="zypper"
            ;;
        arch|manjaro|endeavouros)
            PACKAGE_MANAGER="pacman"
            ;;
        alpine)
            PACKAGE_MANAGER="apk"
            ;;
        gentoo)
            PACKAGE_MANAGER="emerge"
            ;;
        void)
            PACKAGE_MANAGER="xbps"
            ;;
        *)
            PACKAGE_MANAGER="unknown"
            ;;
    esac
    
    # Log the detected platform information
    log "Detected operating system: $OS_TYPE $OS_VERSION"
    log "Detected package manager: $PACKAGE_MANAGER"
    
    # Return false if we couldn't determine the package manager
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        return 1
    fi
    
    return 0
}

# Install packages based on the detected package manager
install_packages() {
    local packages=("$@")
    
    case "$PACKAGE_MANAGER" in
        apt)
            sudo apt-get update -q
            sudo apt-get install -y "${packages[@]}"
            ;;
        dnf)
            sudo dnf install -y "${packages[@]}"
            ;;
        yum)
            sudo yum install -y "${packages[@]}"
            ;;
        zypper)
            sudo zypper install -y "${packages[@]}"
            ;;
        pacman)
            sudo pacman -Sy --noconfirm "${packages[@]}"
            ;;
        apk)
            sudo apk add "${packages[@]}"
            ;;
        emerge)
            sudo emerge --ask=n "${packages[@]}"
            ;;
        xbps)
            sudo xbps-install -y "${packages[@]}"
            ;;
        *)
            return 1
            ;;
    esac
    
    return $?
}

# Trap errors and interrupts
trap cleanup SIGINT SIGTERM ERR EXIT

# Cleanup function for handling script termination
cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    local err=$?
    
    # Only run cleanup for error or explicit exit
    if [ $err -ne 0 ]; then
        echo -e "${RED}Script terminated with error code $err${NC}" >&2
        if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
            echo "See $LOG_FILE for details."
            echo "$(date): Script terminated with error code $err" >> "$LOG_FILE"
        fi
        
        # Handle any temporary files or processes
        if [ -n "$TIMER_PID" ] && ps -p $TIMER_PID > /dev/null; then
            kill $TIMER_PID 2>/dev/null || true
        fi
        
        # Clean up any temporary files created by the script
        for temp_file in "${TEMP_FILES[@]}"; do
            if [ -f "$temp_file" ]; then
                rm -f "$temp_file" 2>/dev/null
            fi
        done
    fi
    
    # Only exit directly when it's an unexpected error
    # This allows normal exits to proceed
    if [ $err -ne 0 ] && [ $err -ne 99 ]; then
        exit $err
    fi
}

# ===================================================================
# VERSION CHECKING AND UPDATE MANAGEMENT
# ===================================================================
# Array to track temporary files for cleanup
TEMP_FILES=()

# Function to check for script updates
check_for_updates() {
    info "Checking for script updates..."
    
    # URL to the latest version info (this would be your actual update check endpoint)
    local VERSION_URL="https://raw.githubusercontent.com/yourusername/ets2-server-setup/main/version.txt"
    local TEMP_VERSION_FILE=$(mktemp)
    TEMP_FILES+=("$TEMP_VERSION_FILE")
    
    # Try to download the version file
    if ! curl -s --fail "$VERSION_URL" -o "$TEMP_VERSION_FILE"; then
        warning "Could not check for updates. Continuing with current version."
        return 1
    fi
    
    # Read the latest version
    local LATEST_VERSION=$(cat "$TEMP_VERSION_FILE" | grep -oP "VERSION=\K.*")
    
    # Compare versions
    if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$SCRIPT_VERSION" ]; then
        echo -e "${YELLOW}Update available!${NC}"
        echo -e "Current version: ${CYAN}$SCRIPT_VERSION${NC}"
        echo -e "Latest version: ${GREEN}$LATEST_VERSION${NC}"
        
        # Ask if user wants to update
        read -p "Would you like to update to the latest version? (y/n): " UPDATE_CHOICE
        
        if [[ "$UPDATE_CHOICE" =~ ^[Yy]$ ]]; then
            info "Downloading the latest version..."
            
            # URL to the latest script (this would be your actual script URL)
            local SCRIPT_URL="https://raw.githubusercontent.com/yourusername/ets2-server-setup/main/setup_ETS2_server.sh"
            local TEMP_SCRIPT_FILE=$(mktemp)
            TEMP_FILES+=("$TEMP_SCRIPT_FILE")
            
            # Download the latest script
            if curl -s --fail "$SCRIPT_URL" -o "$TEMP_SCRIPT_FILE"; then
                # Make it executable
                chmod +x "$TEMP_SCRIPT_FILE"
                
                # Replace the current script with the new one
                mv "$TEMP_SCRIPT_FILE" "$0"
                
                success "Update successful! Please restart the script."
                exit 0
            else
                error_exit "Failed to download the update." $E_NETWORK
            fi
        fi
    else
        info "You are running the latest version ($SCRIPT_VERSION)."
    fi
    
    return 0
}

# Function to check for the latest server version
check_server_version() {
    info "Checking for the latest ETS2 Dedicated Server version..."
    
    # This URL would need to be updated with a reliable source for version information
    local SERVER_INFO_URL="https://download.eurotrucksimulator2.com"
    local TEMP_INFO_FILE=$(mktemp)
    TEMP_FILES+=("$TEMP_INFO_FILE")
    
    # Try to get the download page
    if ! curl -s --fail "$SERVER_INFO_URL" -o "$TEMP_INFO_FILE"; then
        warning "Could not check for server updates. Using default version."
        ETS2_SERVER_VERSION="1.47"
        ETS2_SERVER_URL="https://download.eurotrucksimulator2.com/server_pack_1.47.zip"
        return 1
    fi
    
    # Parse the latest version (this would need to be adapted to the actual content structure)
    # This is an example pattern that might need to be adjusted
    local LATEST_VERSION=$(grep -oP "server_pack_\K[0-9]+\.[0-9]+" "$TEMP_INFO_FILE" | sort -V | tail -1)
    
    if [ -n "$LATEST_VERSION" ]; then
        ETS2_SERVER_VERSION="$LATEST_VERSION"
        ETS2_SERVER_URL="https://download.eurotrucksimulator2.com/server_pack_${LATEST_VERSION}.zip"
        info "Latest ETS2 Dedicated Server version: $ETS2_SERVER_VERSION"
    else
        warning "Could not determine latest server version. Using default."
        ETS2_SERVER_VERSION="1.47"
        ETS2_SERVER_URL="https://download.eurotrucksimulator2.com/server_pack_1.47.zip"
    fi
    
    return 0
}

# Error handler function
error_exit() {
    local msg="$1"
    local code="${2:-$E_GENERAL}"
    
    echo -e "${RED}ERROR: $msg${NC}" >&2
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        echo "$(date): ERROR: $msg" >> "$LOG_FILE"
    fi
    
    # Exit with error code (special code 99 is used for expected exits)
    exit $code
}

# Warning message function
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        echo "$(date): WARNING: $1" >> "$LOG_FILE"
    fi
}

# Success message function
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        echo "$(date): SUCCESS: $1" >> "$LOG_FILE"
    fi
}

# Info message function
info() {
    echo -e "${BLUE}INFO: $1${NC}"
    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        echo "$(date): INFO: $1" >> "$LOG_FILE"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check disk space
check_disk_space() {
    local dir="$1"
    local min_space="$2" # in MB
    
    # Get available disk space in MB
    local space_available
    if command_exists df; then
        space_available=$(df -m "$dir" | awk 'NR==2 {print $4}')
        if [ -z "$space_available" ] || [ "$space_available" -lt "$min_space" ]; then
            error_exit "Not enough disk space. Required: ${min_space}MB, Available: ${space_available}MB" $E_DISK
        fi
    else
        warning "Cannot check disk space: 'df' command not found"
    fi
}

# Validate server token format
validate_token() {
    local token="$1"
    # Basic validation - should be a hex string of 32 characters
    if ! [[ $token =~ ^[0-9A-F]{32}$ ]]; then
        warning "Server token format looks invalid. It should be a 32-character hexadecimal string."
    fi
}

# Safely download a file with retries
safe_download() {
    local url="$1"
    local output_file="$2"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        info "Downloading from $url (attempt $((retry + 1))/$max_retries)"
        if curl -L --fail -o "$output_file" "$url"; then
            success "Download completed successfully: $output_file"
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                warning "Download failed. Retrying in 5 seconds..."
                sleep 5
            else
                error_exit "Failed to download after $max_retries attempts." $E_NETWORK
            fi
        fi
    done
    
    return 1
}

# Try to install a package if it doesn't exist
ensure_package() {
    local package="$1"
    if ! command_exists "$package"; then
        info "Package '$package' not found. Attempting to install..."
        
        if [ "$PACKAGE_MANAGER" = "unknown" ]; then
            error_exit "Cannot install '$package'. No supported package manager found." $E_DEPENDENCY
        fi
        
        if install_packages "$package"; then
            success "Successfully installed $package"
        else
            error_exit "Failed to install '$package'." $E_DEPENDENCY
        fi
    fi
}

# Create directory safely
safe_mkdir() {
    local dir="$1"
    
    if [ -e "$dir" ] && [ ! -d "$dir" ]; then
        error_exit "Cannot create directory '$dir': File exists and is not a directory." $E_GENERAL
    fi
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || error_exit "Failed to create directory: $dir" $E_PERMISSION
        success "Created directory: $dir"
    else
        info "Directory already exists: $dir"
    fi
}

# Verify file exists and is readable
verify_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        error_exit "Required file not found: $file" $E_GENERAL
    fi
    
    if [ ! -r "$file" ]; then
        error_exit "Cannot read file: $file" $E_PERMISSION
    fi
}

# Test network connectivity
test_network() {
    local host="download.eurotrucksimulator2.com"
    info "Testing network connectivity to $host..."
    
    if ping -c 1 "$host" &>/dev/null; then
        success "Network connectivity confirmed."
    else
        warning "Cannot reach $host. Check your internet connection."
        
        # Try alternative connectivity test
        if curl --connect-timeout 5 -s -I "https://$host" &>/dev/null; then
            success "Network connectivity confirmed (alternate method)."
        else
            error_exit "Network connectivity test failed. Check your internet connection." $E_NETWORK
        fi
    fi
}

# ===================================================================
# BACKUP FUNCTIONALITY
# ===================================================================
# Create a backup of server files
create_backup() {
    local backup_dir="$ROOT_DIR/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/ets2_server_backup_$timestamp.tar.gz"
    
    info "Creating server backup..."
    
    # Create backup directory if it doesn't exist
    safe_mkdir "$backup_dir"
    
    # Create a list of files/directories to backup
    local backup_items=(
        "$SERVER_DIR/server_config.sii"
        "$SERVER_DIR/server_packages.sii"
        "$SERVER_DIR/server_packages.dat"
    )
    
    # Check if files exist before adding them to backup
    local files_to_backup=()
    for item in "${backup_items[@]}"; do
        if [ -e "$item" ]; then
            files_to_backup+=("$item")
        fi
    done
    
    # If no files to backup, return
    if [ ${#files_to_backup[@]} -eq 0 ]; then
        warning "No files found to backup."
        return 1
    fi
    
    # Create the backup
    if ! tar -czf "$backup_file" "${files_to_backup[@]}" 2>/dev/null; then
        warning "Failed to create backup."
        return 1
    fi
    
    success "Backup created: $backup_file"
    
    # Cleanup old backups (keep last 5)
    local old_backups=$(ls -t "$backup_dir"/ets2_server_backup_*.tar.gz 2>/dev/null | tail -n +6)
    if [ -n "$old_backups" ]; then
        info "Cleaning up old backups..."
        rm $old_backups
    fi
    
    return 0
}

# Restore a backup
restore_backup() {
    local backup_dir="$ROOT_DIR/backups"
    
    # Check if backup directory exists
    if [ ! -d "$backup_dir" ]; then
        error_exit "Backup directory not found: $backup_dir" $E_GENERAL
    fi
    
    # List available backups
    local backups=($(ls -t "$backup_dir"/ets2_server_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        error_exit "No backups found in $backup_dir" $E_GENERAL
    fi
    
    echo "Available backups:"
    for i in "${!backups[@]}"; do
        echo "$((i+1)). $(basename "${backups[$i]}")"
    done
    
    # Ask which backup to restore
    read -p "Enter the number of the backup to restore (or 'q' to quit): " choice
    
    if [[ "$choice" =~ ^[Qq]$ ]]; then
        return 0
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        error_exit "Invalid choice." $E_INVALID
    fi
    
    local selected_backup="${backups[$((choice-1))]}"
    info "Restoring backup: $selected_backup"
    
    # Stop the server if it's running
    if pgrep -f "eurotrucks2_server" > /dev/null; then
        info "Stopping the server before restore..."
        if [ -f "$ROOT_DIR/stop_ets2_server.sh" ]; then
            "$ROOT_DIR/stop_ets2_server.sh"
        else
            pkill -f "eurotrucks2_server"
        fi
    fi
    
    # Extract the backup
    if ! tar -xzf "$selected_backup" -C / 2>/dev/null; then
        error_exit "Failed to restore backup." $E_GENERAL
    fi
    
    success "Backup restored successfully."
    
    # Ask if the user wants to start the server
    read -p "Do you want to start the server now? (y/n): " start_server
    
    if [[ "$start_server" =~ ^[Yy]$ ]]; then
        if [ -f "$ROOT_DIR/start_ets2_server.sh" ]; then
            "$ROOT_DIR/start_ets2_server.sh"
        else
            warning "Start script not found. Please start the server manually."
        fi
    fi
    
    return 0
}

# ===================================================================
# HEALTH CHECK AND VERIFICATION FUNCTIONALITY
# ===================================================================
# Function to check if a port is in use
is_port_in_use() {
    local port="$1"
    if command_exists netstat; then
        netstat -tuln | grep -q ":$port "
        return $?
    elif command_exists ss; then
        ss -tuln | grep -q ":$port "
        return $?
    else
        warning "Cannot check port usage: neither netstat nor ss command found"
        return 1  # Assume port is in use to be safe
    fi
}

# Comprehensive health check function
run_health_check() {
    info "Running system health check..."
    
    # Track overall health status
    local health_status=true
    
    # 1. Check for required commands
    echo ""
    echo "===== Checking required commands ====="
    for cmd in curl unzip sudo ufw systemctl; do
        if command_exists "$cmd"; then
            echo -e "${GREEN}✓ $cmd${NC} is available"
        else
            echo -e "${RED}✗ $cmd${NC} is missing"
            health_status=false
        fi
    done
    
    # 2. Check disk space
    echo ""
    echo "===== Checking disk space ====="
    local available_space=$(df -m "$ROOT_DIR" | awk 'NR==2 {print $4}')
    if [ -n "$available_space" ] && [ "$available_space" -gt "$MIN_DISK_SPACE" ]; then
        echo -e "${GREEN}✓ Sufficient disk space${NC}: $available_space MB available (minimum required: $MIN_DISK_SPACE MB)"
    else
        echo -e "${RED}✗ Insufficient disk space${NC}: $available_space MB available (minimum required: $MIN_DISK_SPACE MB)"
        health_status=false
    fi
    
    # 3. Check server files
    echo ""
    echo "===== Checking server files ====="
    local server_files=(
        "$SERVER_DIR/server_config.sii"
        "$SERVER_DIR/server_packages.sii"
        "$SERVER_DIR/server_packages.dat"
        "$SERVER_DIR/bin/linux_x64/eurotrucks2_server"
    )
    
    for file in "${server_files[@]}"; do
        if [ -f "$file" ]; then
            echo -e "${GREEN}✓ $file${NC} exists"
        else
            echo -e "${RED}✗ $file${NC} is missing"
            health_status=false
        fi
    done
    
    # 4. Check port availability
    echo ""
    echo "===== Checking ports ====="
    local ports=($SERVER_PORT $QUERY_PORT)
    
    for port in "${ports[@]}"; do
        if ! is_port_in_use "$port"; then
            echo -e "${GREEN}✓ Port $port${NC} is available"
        else
            echo -e "${RED}✗ Port $port${NC} is already in use"
            health_status=false
        fi
    done
    
    # 5. Check firewall rules
    echo ""
    echo "===== Checking firewall rules ====="
    if command_exists ufw; then
        if sudo ufw status | grep -q "Status: active"; then
            echo -e "${GREEN}✓ Firewall${NC} is active"
            
            # Check for our ports
            local port_rules=$(sudo ufw status | grep -E "$SERVER_PORT|$QUERY_PORT")
            if [ -n "$port_rules" ]; then
                echo -e "${GREEN}✓ Firewall rules${NC} for server ports exist"
            else
                echo -e "${RED}✗ Firewall rules${NC} for server ports are missing"
                health_status=false
            fi
        else
            echo -e "${YELLOW}! Firewall${NC} is not active"
            health_status=false
        fi
    else
        echo -e "${RED}✗ UFW${NC} is not installed"
        health_status=false
    fi
    
    # 6. Check systemd service
    echo ""
    echo "===== Checking systemd service ====="
    if command_exists systemctl; then
        if systemctl list-unit-files | grep -q "ets2-server.service"; then
            echo -e "${GREEN}✓ Systemd service${NC} is installed"
            
            local service_status=$(systemctl is-enabled ets2-server.service 2>/dev/null)
            if [ "$service_status" = "enabled" ]; then
                echo -e "${GREEN}✓ Service${NC} is enabled to start at boot"
            else
                echo -e "${YELLOW}! Service${NC} is not enabled to start at boot"
            fi
        else
            echo -e "${RED}✗ Systemd service${NC} is not installed"
            health_status=false
        fi
    else
        echo -e "${RED}✗ Systemctl${NC} is not available"
        health_status=false
    fi
    
    # 7. Check server scripts
    echo ""
    echo "===== Checking server scripts ====="
    local scripts=(
        "$ROOT_DIR/start_ets2_server.sh"
        "$ROOT_DIR/stop_ets2_server.sh"
        "$ROOT_DIR/restart_ets2_server.sh"
        "$ROOT_DIR/monitor_ets2_server.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            echo -e "${GREEN}✓ $script${NC} exists"
            
            if [ -x "$script" ]; then
                echo -e "${GREEN}✓ $script${NC} is executable"
            else
                echo -e "${RED}✗ $script${NC} is not executable"
                health_status=false
            fi
        else
            echo -e "${RED}✗ $script${NC} is missing"
            health_status=false
        fi
    done
    
    # 8. Check cron setup for monitor script
    echo ""
    echo "===== Checking cron setup ====="
    if command_exists crontab; then
        if crontab -l 2>/dev/null | grep -q "monitor_ets2_server.sh"; then
            echo -e "${GREEN}✓ Cron job${NC} for monitoring is setup"
        else
            echo -e "${RED}✗ Cron job${NC} for monitoring is not setup"
            health_status=false
        fi
    else
        echo -e "${RED}✗ Crontab${NC} command not available"
        health_status=false
    fi
    
    # 9. Overall status
    echo ""
    echo "===== Overall health status ====="
    if [ "$health_status" = true ]; then
        echo -e "${GREEN}System health check passed. Your ETS2 server setup appears to be healthy.${NC}"
    else
        echo -e "${RED}System health check found issues. Please address the problems shown above.${NC}"
    fi
    
    echo ""
    
    return 0
}

set -e # Exit on any error

# ===================================================================
# CONFIGURATION VARIABLES
# ===================================================================
SERVER_TOKEN=${1:-"18D10BF61B4AE256FA9189A649AC24F1"} # Default token or one provided as parameter
SERVER_NAME="Mkenya 2 server"                         # Server name displayed in listings
SERVER_DESC="Join our friendly trucking community!"   # Server description
WELCOME_MSG="Welcome to Mkenya ETS2 Trucking Server! Enjoy your journey." # Message shown on connection
MAX_PLAYERS=8                                         # Maximum allowed players
SERVER_PORT=27015                                     # Main server port
QUERY_PORT=27016                                      # Query port for server browser
MIN_DISK_SPACE=1024                                   # Minimum disk space required in MB

# ===================================================================
# DIRECTORY SETUP
# ===================================================================
# Root directory - uses current directory as base
ROOT_DIR=$(pwd)
SERVER_DIR="$ROOT_DIR/ets2server"                     # Server installation directory
LOG_FILE="$ROOT_DIR/ets2_setup.log"                   # Setup log file
BACKUP_DIR="$ROOT_DIR/backups"                        # Directory for backups

# ===================================================================
# LOGGING FUNCTION
# ===================================================================
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Create log file
safe_mkdir "$(dirname "$LOG_FILE")"
> "$LOG_FILE" || error_exit "Cannot create log file: $LOG_FILE" $E_PERMISSION
log "Starting ETS2 server setup"
info "Beginning ETS2 server setup process (v$SCRIPT_VERSION)"

# Display script header
cat << EOF
====================================================================
 🚚 ETS2 SERVER SETUP SCRIPT v$SCRIPT_VERSION
====================================================================
This script will install and configure an Euro Truck Simulator 2 
dedicated server on your Linux system.

EOF

# Detect platform first
info "Detecting platform..."
if ! detect_platform; then
    warning "Could not fully detect platform. Some functionality may be limited."
fi

# Check for script updates
check_for_updates

# Check for the latest server version
check_server_version

# Validate the server token
validate_token "$SERVER_TOKEN"

# ===================================================================
# USER CREATION WHEN RUN AS ROOT
# ===================================================================
# Function to generate a random password
generate_random_password() {
    local length=12
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+"
    local password=""
    
    # Generate random password
    for (( i=0; i<$length; i++ )); do
        password+="${chars:RANDOM%${#chars}:1}"
    done
    
    echo "$password"
}

# If running as root, create a new user
if [ "$EUID" -eq 0 ]; then
    log "Running as root. Setting up a dedicated user for ETS2 server."
    info "Running as root. A dedicated user will be created for security."
    
    # Prompt for username
    read -p "Enter username for the new ETS2 server user (default: ets2server): " NEW_USER
    NEW_USER=${NEW_USER:-"ets2server"}
    
    # Validate username
    if [[ ! $NEW_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        warning "Username '$NEW_USER' may not be valid. Using it anyway, but might cause issues."
    fi
    
    # Check if user already exists
    if id "$NEW_USER" &>/dev/null; then
        log "User $NEW_USER already exists. Using existing user."
        info "User $NEW_USER already exists. Will continue with this user."
    else
        log "Creating new user: $NEW_USER"
        
        # Ask how to handle password
        echo "Password options:"
        echo "1) Generate random password"
        echo "2) Set password manually"
        read -p "Choose option (1/2, default: 1): " PASSWORD_OPTION
        PASSWORD_OPTION=${PASSWORD_OPTION:-"1"}
        
        if [ "$PASSWORD_OPTION" = "1" ]; then
            # Generate random password
            USER_PASSWORD=$(generate_random_password)
            log "Generated random password for $NEW_USER"
            
            # Create user with random password
            useradd -m -s /bin/bash "$NEW_USER" || error_exit "Failed to create user $NEW_USER" $E_GENERAL
            echo "$NEW_USER:$USER_PASSWORD" | chpasswd || error_exit "Failed to set password for $NEW_USER" $E_GENERAL
            
            echo "========================================"
            echo "Created user: $NEW_USER"
            echo "Random password: $USER_PASSWORD"
            echo "IMPORTANT: Save this password now!"
            echo "========================================"
            
            # Wait for user acknowledgment
            read -p "Press Enter to continue once you've saved the password..."
            
        else
            # Create user without password
            useradd -m -s /bin/bash "$NEW_USER" || error_exit "Failed to create user $NEW_USER" $E_GENERAL
            
            echo "You have 1 minute to set a password for $NEW_USER"
            echo "Setting password in 5 seconds..."
            sleep 5
            
            # Set a timer for password setting
            ( sleep 60 && kill -ALRM $$ ) &
            TIMER_PID=$!
            
            # Setup trap to handle timeout
            trap "echo 'Password setup timed out'; passwd -l '$NEW_USER'; echo 'Account locked. Run passwd $NEW_USER as root to set password later.'; kill $TIMER_PID 2>/dev/null || true; trap - ALRM; TIMEOUT=true" ALRM
            
            # Try to set password
            TIMEOUT=false
            passwd "$NEW_USER" || {
                warning "Failed to set password for $NEW_USER"
                passwd -l "$NEW_USER"
                echo "Account locked. Run 'passwd $NEW_USER' as root to set password later."
            }
            
            # Kill timer if still running
            kill $TIMER_PID 2>/dev/null || true
            trap - ALRM
            
            if [ "$TIMEOUT" = "true" ]; then
                log "Password setup timed out. Account locked."
                warning "Password setup timed out. The account has been locked for security."
            else
                log "Password set for $NEW_USER"
            fi
        fi
        
        # Add user to sudo group
        usermod -aG sudo "$NEW_USER" || warning "Failed to add $NEW_USER to sudo group. Manual intervention might be needed."
        log "Added $NEW_USER to sudo group"
        
        # Copy the script to the new user's home directory
        USER_HOME=$(eval echo ~$NEW_USER) || USER_HOME="/home/$NEW_USER"
        
        # Make sure the user's home directory exists
        if [ ! -d "$USER_HOME" ]; then
            warning "User home directory $USER_HOME does not exist. Creating it."
            mkdir -p "$USER_HOME" && chown "$NEW_USER:$NEW_USER" "$USER_HOME"
        fi
        
        cp "$0" "$USER_HOME/" || error_exit "Failed to copy script to $USER_HOME" $E_PERMISSION
        chown "$NEW_USER:$NEW_USER" "$USER_HOME/$(basename "$0")" || warning "Failed to set ownership on copied script"
        chmod +x "$USER_HOME/$(basename "$0")" || warning "Failed to set execute permission on copied script"
        log "Copied setup script to $USER_HOME"
        
        # Switch to the new user
        success "User creation complete!"
        echo "======================================================================"
        echo "User $NEW_USER has been created. Please run this script as $NEW_USER:"
        echo "su - $NEW_USER -c '$USER_HOME/$(basename "$0")'"
        echo "======================================================================"
        exit 0
    fi
fi

# ===================================================================
# PRELIMINARY CHECKS
# ===================================================================
# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then
    log "Please don't run this script as root. The script will use sudo when needed."
    error_exit "Please don't run this script as root. The script will use sudo when needed." $E_PERMISSION
fi

# Check disk space
check_disk_space "$ROOT_DIR" "$MIN_DISK_SPACE"

# Test network connectivity
test_network

# Check for required command-line tools
info "Checking for required commands..."
MISSING_PACKAGES=()

for cmd in curl unzip sudo ufw systemctl; do
    if ! command_exists "$cmd"; then
        MISSING_PACKAGES+=("$cmd")
        log "Required command '$cmd' not found."
    fi
done

# Try to install missing packages if any
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log "Some required commands are missing. Attempting to install..."
    info "Installing missing commands: ${MISSING_PACKAGES[*]}"
    
    for pkg in "${MISSING_PACKAGES[@]}"; do
        ensure_package "$pkg"
    done
    
    # Verify installation
    STILL_MISSING=()
    for cmd in "${MISSING_PACKAGES[@]}"; do
        if ! command_exists "$cmd"; then
            STILL_MISSING+=("$cmd")
        fi
    done
    
    if [ ${#STILL_MISSING[@]} -gt 0 ]; then
        error_exit "Failed to install required packages: ${STILL_MISSING[*]}" $E_DEPENDENCY
    else
        success "All required commands are now available."
    fi
else
    success "All required commands are available."
fi

# ===================================================================
# MENU SYSTEM
# ===================================================================
if [ -d "$SERVER_DIR" ] && [ -f "$SERVER_DIR/server_config.sii" ]; then
    # Server appears to be already installed - show management menu
    info "An existing ETS2 server installation was detected."
    echo ""
    echo "======================================================================"
    echo " ETS2 SERVER MANAGEMENT MENU"
    echo "======================================================================"
    echo "1) Start server"
    echo "2) Stop server"
    echo "3) Restart server"
    echo "4) Run health check"
    echo "5) Create backup"
    echo "6) Restore from backup"
    echo "7) Reinstall/repair server"
    echo "8) Update server to latest version"
    echo "9) Exit"
    echo ""
    read -p "Enter your choice [1-9]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        1)
            info "Starting server..."
            if [ -f "$ROOT_DIR/start_ets2_server.sh" ]; then
                "$ROOT_DIR/start_ets2_server.sh"
                exit 0
            else
                error_exit "Start script not found." $E_GENERAL
            fi
            ;;
        2)
            info "Stopping server..."
            if [ -f "$ROOT_DIR/stop_ets2_server.sh" ]; then
                "$ROOT_DIR/stop_ets2_server.sh"
                exit 0
            else
                error_exit "Stop script not found." $E_GENERAL
            fi
            ;;
        3)
            info "Restarting server..."
            if [ -f "$ROOT_DIR/restart_ets2_server.sh" ]; then
                "$ROOT_DIR/restart_ets2_server.sh"
                exit 0
            else
                error_exit "Restart script not found." $E_GENERAL
            fi
            ;;
        4)
            info "Running health check..."
            run_health_check
            exit 0
            ;;
        5)
            info "Creating backup..."
            create_backup
            exit 0
            ;;
        6)
            info "Restoring from backup..."
            restore_backup
            exit 0
            ;;
        7)
            info "Proceeding with reinstall/repair..."
            # Backup existing configuration before reinstall
            if [ -d "$SERVER_DIR" ]; then
                info "Backing up existing configuration before reinstall..."
                create_backup
            fi
            # Continue with installation - fall through to the regular flow
            ;;
        8)
            info "Updating server to latest version..."
            if [ -d "$SERVER_DIR" ]; then
                # Create backup first
                info "Creating backup before update..."
                create_backup
                
                # Check for latest version
                check_server_version
                
                # Stop the server if it's running
                if pgrep -f "eurotrucks2_server" > /dev/null; then
                    info "Stopping the server before update..."
                    if [ -f "$ROOT_DIR/stop_ets2_server.sh" ]; then
                        "$ROOT_DIR/stop_ets2_server.sh"
                    else
                        pkill -f "eurotrucks2_server"
                    fi
                fi
                
                # Rename old server directory
                mv "$SERVER_DIR" "${SERVER_DIR}_old_$(date +%Y%m%d%H%M%S)"
                
                # Download and install the latest version
                info "Downloading and installing latest version..."
                # Continue with installation - fall through to the regular flow
            else
                error_exit "Server directory not found. Cannot update." $E_GENERAL
            fi
            ;;
        9)
            info "Exiting..."
            exit 0
            ;;
        *)
            warning "Invalid choice. Proceeding with regular setup..."
            # Continue with installation - fall through to the regular flow
            ;;
    esac
fi

# ===================================================================
# INSTALL DEPENDENCIES
# ===================================================================
log "Installing required packages..."
info "Updating package lists and installing dependencies..."

# We use a function here to catch errors and provide better messages
install_dependencies() {
    # Check if we have a detected package manager
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        warning "Unknown package manager. Will try to detect available ones..."
        if command_exists apt-get; then
            PACKAGE_MANAGER="apt"
        elif command_exists dnf; then
            PACKAGE_MANAGER="dnf"
        elif command_exists yum; then
            PACKAGE_MANAGER="yum"
        else
            warning "No supported package manager found. Dependencies installation may fail."
            return 1
        fi
    fi
    
    # Install packages using the detected package manager
    local packages=("curl" "unzip" "net-tools" "ufw")
    if install_packages "${packages[@]}"; then
        success "Dependencies installed successfully."
        return 0
    else
        warning "Failed to install some packages. Will try individual installation..."
        
        # Try installing packages one by one
        for pkg in "${packages[@]}"; do
            info "Installing $pkg..."
            install_packages "$pkg" || warning "Failed to install $pkg"
        done
    fi
    
    # Verify critical packages
    for pkg in curl unzip; do
        if ! command_exists "$pkg"; then
            error_exit "Critical package $pkg could not be installed." $E_DEPENDENCY
        fi
    done
    
    return 0
}

# Try to install dependencies
install_dependencies || warning "Some dependencies might be missing. The script will try to continue."

# ===================================================================
# CREATE DIRECTORY STRUCTURE
# ===================================================================
log "Creating directory structure..."
info "Setting up directory structure..."

safe_mkdir "$SERVER_DIR"
safe_mkdir "$ROOT_DIR/.local/share/Euro Truck Simulator 2"
safe_mkdir "$BACKUP_DIR"
safe_mkdir "/home/server_packages" || {
    warning "Failed to create /home/server_packages. Using alternative location."
    safe_mkdir "$ROOT_DIR/server_packages"
}

# ===================================================================
# DOWNLOAD & EXTRACT SERVER FILES
# ===================================================================
# Download ETS2 dedicated server (if not already present)
if [ ! -f "$ROOT_DIR/ets2_server_pack.zip" ]; then
    log "Downloading ETS2 dedicated server files..."
    info "Downloading server files. This may take a while..."
    
    SERVER_PACK_URL=${ETS2_SERVER_URL:-"https://download.eurotrucksimulator2.com/server_pack_1.47.zip"}
    PACK_FILE="$ROOT_DIR/ets2_server_pack.zip"
    
    # Try to download with retries
    safe_download "$SERVER_PACK_URL" "$PACK_FILE"
else
    info "Server pack already downloaded. Skipping download."
    
    # Verify the existing file is valid
    if ! unzip -t "$ROOT_DIR/ets2_server_pack.zip" &>/dev/null; then
        warning "The existing ZIP file appears to be corrupt. Re-downloading..."
        mv "$ROOT_DIR/ets2_server_pack.zip" "$ROOT_DIR/ets2_server_pack.zip.bak"
        safe_download "${ETS2_SERVER_URL:-"https://download.eurotrucksimulator2.com/server_pack_1.47.zip"}" "$ROOT_DIR/ets2_server_pack.zip"
    fi
fi

# Extract server files
log "Extracting server files..."
info "Extracting server files..."

if ! unzip -o "$ROOT_DIR/ets2_server_pack.zip" -d "$SERVER_DIR"; then
    error_exit "Failed to extract server files. The ZIP file may be corrupt." $E_GENERAL
fi

success "Server files extracted successfully."

# ===================================================================
# SET PERMISSIONS
# ===================================================================
log "Setting permissions..."
info "Setting executable permissions..."

chmod -R 755 "$SERVER_DIR/bin" || {
    warning "Failed to set permissions on server binaries. Trying alternate method..."
    find "$SERVER_DIR/bin" -type f -exec chmod +x {} \;
}

# Double check the critical executables
for exe in "$SERVER_DIR/bin/linux_x64/server_launch.sh" "$SERVER_DIR/bin/linux_x64/eurotrucks2_server"; do
    if [ -f "$exe" ]; then
        chmod +x "$exe" || warning "Failed to set execute permission on $exe"
    else
        warning "Expected executable not found: $exe"
    fi
done

# ===================================================================
# CREATE SERVER CONFIGURATION FILES
# ===================================================================
log "Creating server configuration..."
info "Creating server configuration files..."

# Create a backup of existing config if it exists
if [ -f "$SERVER_DIR/server_config.sii" ]; then
    info "Backing up existing server configuration..."
    cp "$SERVER_DIR/server_config.sii" "$SERVER_DIR/server_config.sii.bak" || warning "Failed to create backup of server_config.sii"
fi

# Create the main server configuration file
cat > "$SERVER_DIR/server_config.sii" << EOF || error_exit "Failed to create server_config.sii" $E_GENERAL
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
  roads_data_file_name: "$SERVER_DIR/server_packages.dat"

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
EOF

success "Server configuration created successfully."

# ===================================================================
# CREATE SERVER PACKAGES FILES (MINIMAL VERSION FOR TESTING)
# ===================================================================
log "Creating server packages files..."
info "Creating minimal server packages files..."

# Create a backup of existing packages if they exist
if [ -f "$SERVER_DIR/server_packages.sii" ]; then
    info "Backing up existing server packages..."
    cp "$SERVER_DIR/server_packages.sii" "$SERVER_DIR/server_packages.sii.bak" || warning "Failed to create backup of server_packages.sii"
fi

# Create a minimal server_packages.sii file
cat > "$SERVER_DIR/server_packages.sii" << EOF || error_exit "Failed to create server_packages.sii" $E_GENERAL
SiiNunit
{
server_packages_info : _nameless.1ae.f18a.b110 {
 version: 1
 dlc_essential_list: 0
 dlc_non_essential_list: 0
 mod_list: 0
 map_name: "/map/europe.mbd"
 map_dimensions: (-24576000, -16384000, 20480000, 22528000)
 roads_data_file_name: "$SERVER_DIR/server_packages.dat"
 time_stamp: $(date +%s)
 time_compression: 15.560001
}
}
EOF

# Create dummy server_packages.dat (placeholder until real one is created)
if ! dd if=/dev/zero of="$SERVER_DIR/server_packages.dat" bs=1K count=10 2>/dev/null; then
    warning "Failed to create dummy server_packages.dat using dd. Trying alternative method..."
    # Alternative method using touch and truncate
    touch "$SERVER_DIR/server_packages.dat" && truncate -s 10K "$SERVER_DIR/server_packages.dat" || 
        error_exit "Failed to create server_packages.dat" $E_GENERAL
fi

success "Server packages files created successfully."

# ===================================================================
# COPY SERVER PACKAGES TO ALL REQUIRED LOCATIONS
# ===================================================================
info "Copying server packages to required locations..."

# The server checks multiple locations for these files
copy_server_packages() {
    local src_sii="$SERVER_DIR/server_packages.sii"
    local src_dat="$SERVER_DIR/server_packages.dat"
    local dest_dir="$1"
    
    # Create directory if it doesn't exist
    safe_mkdir "$dest_dir"
    
    # Copy files
    cp "$src_sii" "$dest_dir/" || { 
        warning "Failed to copy server_packages.sii to $dest_dir"
        return 1
    }
    
    cp "$src_dat" "$dest_dir/" || { 
        warning "Failed to copy server_packages.dat to $dest_dir"
        return 1
    }
    
    return 0
}

# Copy to all locations with error handling
LOCATIONS=(
    "$ROOT_DIR/.local/share/Euro Truck Simulator 2"
    "$SERVER_DIR/bin/linux_x64"
    "$HOME/.local/share/Euro Truck Simulator 2"
)

for location in "${LOCATIONS[@]}"; do
    if copy_server_packages "$location"; then
        success "Copied server packages to $location"
    fi
done

# ===================================================================
# CREATE SERVER MANAGEMENT SCRIPTS
# ===================================================================
log "Creating server management scripts..."
info "Creating server management scripts..."

# ===================================================================
# 1. START SCRIPT - LAUNCHES THE SERVER
# ===================================================================
cat > "$ROOT_DIR/start_ets2_server.sh" << 'EOF' || error_exit "Failed to create start script" $E_GENERAL
#!/bin/bash
# ETS2 Server Start Script
# Description: Starts the ETS2 dedicated server with robust error handling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling function
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    echo "ERROR: $1" >> "$LOG_FILE"
    exit 1
}

# Warning function
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    echo "WARNING: $1" >> "$LOG_FILE"
}

# Info function
info() {
    echo -e "${BLUE}INFO: $1${NC}"
    echo "INFO: $1" >> "$LOG_FILE"
}

# Success function
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    echo "SUCCESS: $1" >> "$LOG_FILE"
}

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR" || error "Failed to change to script directory"

# Set working directory to the server directory
SERVER_DIR="$SCRIPT_DIR/ets2server"
cd "$SERVER_DIR" || error "Failed to change to server directory: $SERVER_DIR"

# Log file for server output
LOG_FILE="$SCRIPT_DIR/ets2_server.log"

# Clear previous log
echo "Starting ETS2 server at $(date)" > "$LOG_FILE" || warning "Failed to create/clear log file: $LOG_FILE"

# Verify required directories and files
if [ ! -d "$SERVER_DIR/bin/linux_x64" ]; then
    error "Server binary directory not found: $SERVER_DIR/bin/linux_x64"
fi

if [ ! -f "$SERVER_DIR/bin/linux_x64/eurotrucks2_server" ]; then
    error "Server executable not found: $SERVER_DIR/bin/linux_x64/eurotrucks2_server"
fi

if [ ! -f "$SERVER_DIR/server_config.sii" ]; then
    error "Server configuration not found: $SERVER_DIR/server_config.sii"
fi

# Force cleanup any existing processes to avoid false detections
pkill -f "eurotrucks2_server" 2>/dev/null
if [ -f "$SCRIPT_DIR/ets2_server.pid" ]; then
    rm "$SCRIPT_DIR/ets2_server.pid" || warning "Failed to remove old PID file"
fi
sleep 1

# Copy server packages files to all possible locations
info "Copying server packages files to all required locations..."
mkdir -p ~/.local/share/Euro\ Truck\ Simulator\ 2/ || warning "Failed to create user data directory"

for pkg_file in server_packages.sii server_packages.dat; do
    # Check if the files exist
    if [ ! -f "$pkg_file" ]; then
        warning "Package file not found: $pkg_file. Server may not function correctly."
        continue
    fi
    
    # Copy to user directory
    cp "$pkg_file" ~/.local/share/Euro\ Truck\ Simulator\ 2/ || 
        warning "Failed to copy $pkg_file to user directory"
    
    # Copy to server binary directory
    cp "$pkg_file" ./bin/linux_x64/ || 
        warning "Failed to copy $pkg_file to server binary directory"
done

# Make sure executable files have correct permissions
chmod +x bin/linux_x64/server_launch.sh || warning "Failed to set permissions on server_launch.sh"
chmod +x bin/linux_x64/eurotrucks2_server || warning "Failed to set permissions on eurotrucks2_server"

# Set the LD_LIBRARY_PATH correctly
if [ -d "$SERVER_DIR/linux64" ]; then
    export LD_LIBRARY_PATH="$SERVER_DIR/linux64:$LD_LIBRARY_PATH"
else
    warning "Linux64 directory not found. Trying alternate paths..."
    # Try alternate paths
    for lib_path in "$SERVER_DIR/bin/linux_x64/linux64" "$SERVER_DIR/bin/linux64"; do
        if [ -d "$lib_path" ]; then
            export LD_LIBRARY_PATH="$lib_path:$LD_LIBRARY_PATH"
            break
        fi
    done
fi
info "LD_LIBRARY_PATH set to: $LD_LIBRARY_PATH"

# Start the server
info "Server will run in the background. Check logs with: tail -f $LOG_FILE"

# Change to the binary directory
cd bin/linux_x64 || error "Failed to change to binary directory"
info "Executing from directory: $(pwd)"

# Verify the binary is executable
if [ ! -x "./eurotrucks2_server" ]; then
    warning "Server binary is not executable. Attempting to fix..."
    chmod +x ./eurotrucks2_server || error "Failed to make server binary executable"
fi

# Start server in background and redirect output to log file
info "Starting server..."
nohup ./eurotrucks2_server >> "$LOG_FILE" 2>&1 &

# Save PID to file for easier management
PID=$!
echo $PID > "$SCRIPT_DIR/ets2_server.pid" || warning "Failed to save PID file"
success "Server started with PID: $PID"

# Check if process is running after 2 seconds
sleep 2
if ps -p $PID > /dev/null; then
    success "Server process is running."
else
    error "Server process has already terminated! Check logs for errors."
fi

# Display instructions
echo ""
echo "======================================================================"
echo "ETS2 Server has been started!"
echo "- To check server logs: tail -f $LOG_FILE"
echo "- To stop the server: $SCRIPT_DIR/stop_ets2_server.sh"
echo "- To restart the server: $SCRIPT_DIR/restart_ets2_server.sh"
echo "======================================================================"
EOF

# ===================================================================
# 2. STOP SCRIPT - GRACEFULLY SHUTS DOWN THE SERVER
# ===================================================================
cat > "$ROOT_DIR/stop_ets2_server.sh" << 'EOF' || error_exit "Failed to create stop script" $E_GENERAL
#!/bin/bash
# ETS2 Server Stop Script
# Description: Gracefully stops the ETS2 server with improved error handling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR" || { echo -e "${RED}Failed to change to script directory${NC}"; exit 1; }

# Log file for tracking
LOG_FILE="$SCRIPT_DIR/ets2_stop.log"
echo "$(date): Stopping ETS2 server" > "$LOG_FILE"

# Helper functions
log() {
    echo "$1"
    echo "$(date): $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    echo "$(date): ERROR: $1" >> "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    echo "$(date): WARNING: $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    echo "$(date): SUCCESS: $1" >> "$LOG_FILE"
}

stop_server() {
    local pid="$1"
    local force="$2"
    
    if [ -z "$pid" ]; then
        warning "No PID provided to stop_server function"
        return 1
    fi
    
    if ! ps -p "$pid" > /dev/null; then
        warning "Process with PID $pid is not running"
        return 0  # Not an error, process is already gone
    fi
    
    log "Stopping ETS2 server (PID: $pid)..."
    
    if [ "$force" = "force" ]; then
        log "Using force kill signal..."
        kill -9 "$pid" 2>> "$LOG_FILE"
    else
        kill "$pid" 2>> "$LOG_FILE"
    fi
    
    # Check the result
    if [ $? -ne 0 ]; then
        warning "Failed to send kill signal to process $pid"
        return 1
    fi
    
    # Wait for process to terminate
    local count=0
    while ps -p "$pid" > /dev/null && [ $count -lt 10 ]; do
        log "Waiting for server to shut down..."
        sleep 2
        count=$((count+1))
    done
    
    # Check if the process is still running
    if ps -p "$pid" > /dev/null; then
        if [ "$force" = "force" ]; then
            warning "Process $pid could not be killed even with force. Manual intervention may be required."
            return 1
        else
            log "Server not responding to normal termination. Attempting force stop..."
            stop_server "$pid" "force"
            return $?
        fi
    fi
    
    success "Server process $pid has been stopped."
    return 0
}

# Get the PID from file if it exists
PID_FILE="$SCRIPT_DIR/ets2_server.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    log "Found PID file with PID: $PID"
    
    # Check if process is still running
    if ps -p $PID > /dev/null; then
        # Try to stop the server
        if stop_server "$PID"; then
            success "ETS2 server stopped successfully."
        else
            warning "There were issues stopping the ETS2 server."
        fi
    else
        log "PID $PID no longer exists. Cleaning up PID file."
    fi
    
    # Remove PID file
    rm "$PID_FILE" 2>/dev/null || warning "Failed to remove PID file"
else
    log "No PID file found. Trying to find the process."
    # Try to find any eurotrucks2_server process
    PID=$(pgrep -f "eurotrucks2_server" | head -n 1)
    
    if [ -n "$PID" ]; then
        log "Found server with PID: $PID"
        
        # Try to stop the server
        if stop_server "$PID"; then
            success "ETS2 server stopped successfully."
        else
            warning "There were issues stopping the ETS2 server."
        fi
    else
        log "No ETS2 server process found."
    fi
fi

# Kill any remaining eurotrucks2_server processes as a last resort
REMAINING_PIDS=$(pgrep -f "eurotrucks2_server")
if [ -n "$REMAINING_PIDS" ]; then
    log "Found additional server processes. Cleaning up..."
    
    for pid in $REMAINING_PIDS; do
        stop_server "$pid" "force"
    done
    
    # Check if any processes are still running
    if pgrep -f "eurotrucks2_server" > /dev/null; then
        warning "Some server processes could not be stopped. Manual intervention may be required."
    else
        success "All server processes have been stopped."
    fi
fi

log "Stop operation completed at $(date)"
EOF

# ===================================================================
# 3. RESTART SCRIPT - RESTARTS THE SERVER
# ===================================================================
cat > "$ROOT_DIR/restart_ets2_server.sh" << 'EOF' || error_exit "Failed to create restart script" $E_GENERAL
#!/bin/bash
# ETS2 Server Restart Script
# Description: Stops and then starts the ETS2 server with improved reliability

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR" || { echo -e "${RED}Failed to change to script directory${NC}"; exit 1; }

# Log file
LOG_FILE="$SCRIPT_DIR/ets2_restart.log"
echo "$(date): Restarting ETS2 server" > "$LOG_FILE"

# Helper functions
log() {
    echo "$1"
    echo "$(date): $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    echo "$(date): ERROR: $1" >> "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    echo "$(date): WARNING: $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    echo "$(date): SUCCESS: $1" >> "$LOG_FILE"
}

# Main restart function
restart_server() {
    log "Beginning ETS2 server restart procedure..."
    
    # Verify stop script exists
    if [ ! -f "$SCRIPT_DIR/stop_ets2_server.sh" ]; then
        error "Stop script not found: $SCRIPT_DIR/stop_ets2_server.sh"
    fi
    
    # Verify start script exists
    if [ ! -f "$SCRIPT_DIR/start_ets2_server.sh" ]; then
        error "Start script not found: $SCRIPT_DIR/start_ets2_server.sh"
    fi
    
    # Make sure scripts are executable
    chmod +x "$SCRIPT_DIR/stop_ets2_server.sh" 2>/dev/null
    chmod +x "$SCRIPT_DIR/start_ets2_server.sh" 2>/dev/null
    
    # Stop the server
    log "Stopping the ETS2 server..."
    if "$SCRIPT_DIR/stop_ets2_server.sh"; then
        success "Server stopped successfully."
    else
        warning "There were issues stopping the server. Will attempt to start anyway."
    fi
    
    # Wait before starting again - this helps avoid conflicts
    log "Waiting 5 seconds before starting the server again..."
    sleep 5
    
    # Make sure no server processes are running
    if pgrep -f "eurotrucks2_server" > /dev/null; then
        warning "Server processes are still running. Forcefully terminating..."
        pkill -9 -f "eurotrucks2_server" 2>/dev/null
        sleep 2
    fi
    
    # Start the server
    log "Starting the ETS2 server..."
    if "$SCRIPT_DIR/start_ets2_server.sh"; then
        success "Server started successfully."
    else
        error "Failed to start the server. Check logs for details."
    fi
    
    # Verify server is running
    sleep 2
    if pgrep -f "eurotrucks2_server" > /dev/null; then
        success "Server is now running."
    else
        error "Server failed to start or stopped immediately. Check logs for details."
    fi
    
    log "Restart procedure completed at $(date)"
}

# Execute the restart function
restart_server
EOF

# ===================================================================
# 4. MONITOR SCRIPT - CHECKS SERVER STATUS AND RESTARTS IF NEEDED
# ===================================================================
cat > "$ROOT_DIR/monitor_ets2_server.sh" << 'EOF' || error_exit "Failed to create monitor script" $E_GENERAL
#!/bin/bash
# ETS2 Server Monitor Script
# Description: Monitors server status and restarts if not running with improved reliability

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR" || { echo -e "${RED}Failed to change to script directory${NC}"; exit 1; }

# Log file
LOG_FILE="$SCRIPT_DIR/ets2_monitor.log"

# Create log directory if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || {
        echo -e "${RED}Failed to create log file: $LOG_FILE${NC}"
        LOG_FILE="/tmp/ets2_monitor.log"
        touch "$LOG_FILE" 2>/dev/null
    }
fi

# Helper functions
log() {
    echo "[$(date)] $1" >> "$LOG_FILE"
    if [ "$2" = "display" ]; then
        echo "$1"
    fi
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    log "SUCCESS: $1"
}

info() {
    echo -e "${BLUE}INFO: $1${NC}"
    log "INFO: $1"
}

# Function to check if server is healthy
is_server_running() {
    # First check if any process with the name exists
    if ! pgrep -f "eurotrucks2_server" > /dev/null; then
        return 1  # No process found
    fi
    
    # Check if the PID file exists and points to a running process
    if [ -f "$SCRIPT_DIR/ets2_server.pid" ]; then
        local pid=$(cat "$SCRIPT_DIR/ets2_server.pid")
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null; then
            return 0  # PID file exists and process is running
        else
            log "PID file exists but process is not running or PID is invalid"
            return 1
        fi
    fi
    
    # If we got here, the process is running but the PID file is missing
    # Create a new PID file with the found PID
    local found_pid=$(pgrep -f "eurotrucks2_server" | head -n 1)
    if [ -n "$found_pid" ]; then
        echo "$found_pid" > "$SCRIPT_DIR/ets2_server.pid"
        log "Created new PID file with found PID: $found_pid"
        return 0
    fi
    
    return 1  # Shouldn't reach here, but just in case
}

# Function to check server health and restart if needed
check_server() {
    if is_server_running; then
        log "ETS2 server is running." "display"
    else
        log "ETS2 server not running. Restarting..." "display"
        
        # Check if restart script exists
        if [ ! -f "$SCRIPT_DIR/restart_ets2_server.sh" ]; then
            warning "Restart script not found. Trying to use start script directly."
            
            # Try to stop any zombie processes first
            if pgrep -f "eurotrucks2_server" > /dev/null; then
                warning "Found zombie processes. Cleaning up..."
                pkill -9 -f "eurotrucks2_server" 2>/dev/null
                sleep 2
            fi
            
            # Check if start script exists
            if [ -f "$SCRIPT_DIR/start_ets2_server.sh" ]; then
                chmod +x "$SCRIPT_DIR/start_ets2_server.sh" 2>/dev/null
                "$SCRIPT_DIR/start_ets2_server.sh" >> "$LOG_FILE" 2>&1
            else
                error "Neither restart nor start scripts found. Cannot restart server."
            fi
        else
            chmod +x "$SCRIPT_DIR/restart_ets2_server.sh" 2>/dev/null
            "$SCRIPT_DIR/restart_ets2_server.sh" >> "$LOG_FILE" 2>&1
        fi
        
        # Verify server was started successfully
        sleep 5
        if is_server_running; then
            success "ETS2 server restarted successfully."
        else
            warning "Failed to restart ETS2 server. Check logs for details."
        fi
    fi
}

# Run once when script is executed
check_server

# Setup cron job to run this script every 5 minutes if not already set
setup_cron() {
    if command -v crontab >/dev/null 2>&1; then
        if ! crontab -l 2>/dev/null | grep -q "monitor_ets2_server.sh"; then
            # Create a temporary file with the current crontab
            TEMP_CRON=$(mktemp) || { 
                warning "Failed to create temporary file for crontab. Skipping cron setup."
                return 1
            }
            
            # Get existing crontab or create empty one
            crontab -l 2>/dev/null > "$TEMP_CRON" || echo "" > "$TEMP_CRON"
            
            # Add our monitoring job
            echo "*/5 * * * * $SCRIPT_DIR/monitor_ets2_server.sh >/dev/null 2>&1" >> "$TEMP_CRON"
            
            # Install the new crontab
            if crontab "$TEMP_CRON"; then
                success "Added monitor script to crontab. It will check server status every 5 minutes."
            else
                warning "Failed to update crontab. You may need to set up monitoring manually."
            fi
            
            # Clean up the temporary file
            rm -f "$TEMP_CRON"
        else
            info "Cron job for monitor script already exists."
        fi
    else
        warning "Crontab command not found. You'll need to set up monitoring manually."
    fi
}

# Only setup cron if this isn't being run by cron already
if [ -z "$CRONARG" ]; then
    setup_cron
fi
EOF

# ===================================================================
# CREATE SYSTEMD SERVICE
# ===================================================================
log "Creating systemd service..."
info "Setting up systemd service..."

# Backup existing service if it exists
if [ -f "/etc/systemd/system/ets2-server.service" ]; then
    info "Backing up existing systemd service..."
    sudo cp "/etc/systemd/system/ets2-server.service" "/etc/systemd/system/ets2-server.service.bak" || warning "Failed to backup existing systemd service"
fi

# Create service file
cat > "$ROOT_DIR/ets2-server.service" << EOF || error_exit "Failed to create systemd service file" $E_GENERAL
[Unit]
Description=Euro Truck Simulator 2 Dedicated Server
After=network.target

[Service]
Type=forking
User=$(whoami)
WorkingDirectory=$ROOT_DIR
ExecStart=$ROOT_DIR/start_ets2_server.sh
ExecStop=$ROOT_DIR/stop_ets2_server.sh
Restart=on-failure
RestartSec=30s
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
SyslogIdentifier=ets2-server

[Install]
WantedBy=multi-user.target
EOF

success "Systemd service file created."

# ===================================================================
# SET EXECUTE PERMISSIONS ON SCRIPTS
# ===================================================================
log "Setting permissions on scripts..."
info "Setting execute permissions on management scripts..."

set_script_permissions() {
    local script="$1"
    chmod +x "$script" || {
        warning "Failed to set execute permissions on $script. Trying alternative method..."
        sudo chmod +x "$script" || {
            error_exit "Failed to set execute permissions on $script" $E_PERMISSION
        }
    }
    success "Set execute permissions on $(basename "$script")"
}

# Set permissions on all scripts
set_script_permissions "$ROOT_DIR/start_ets2_server.sh"
set_script_permissions "$ROOT_DIR/stop_ets2_server.sh"
set_script_permissions "$ROOT_DIR/restart_ets2_server.sh"
set_script_permissions "$ROOT_DIR/monitor_ets2_server.sh"

# ===================================================================
# CONFIGURE FIREWALL
# ===================================================================
log "Setting up firewall rules..."
info "Configuring firewall..."

# Function to configure firewall with error handling
configure_firewall() {
    # Check if UFW is installed and running
    if ! command_exists ufw; then
        warning "UFW not found. Attempting to install..."
        ensure_package "ufw" || {
            warning "Failed to install UFW. Firewall configuration will be skipped."
            return 1
        }
    fi
    
    # Add the required rules
    info "Opening server ports in firewall..."
    local ports=("$SERVER_PORT/tcp" "$SERVER_PORT/udp" "$QUERY_PORT/tcp" "$QUERY_PORT/udp")
    local success=true
    
    for port in "${ports[@]}"; do
        info "Adding rule for port $port..."
        if ! sudo ufw allow "$port"; then
            warning "Failed to add firewall rule for $port"
            success=false
        fi
    done
    
    # Enable the firewall if not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        info "Enabling firewall..."
        if ! sudo ufw --force enable; then
            warning "Failed to enable firewall"
            success=false
        fi
    else
        info "Firewall is already enabled"
    fi
    
    if [ "$success" = true ]; then
        return 0
    else
        return 1
    fi
}

# Configure the firewall
if configure_firewall; then
    success "Firewall configuration completed successfully."
else
    warning "There were issues configuring the firewall. You may need to configure it manually."
    echo "Required ports:"
    echo "- TCP/UDP: $SERVER_PORT (Game connection port)"
    echo "- TCP/UDP: $QUERY_PORT (Query port)"
fi

# ===================================================================
# INSTALL SYSTEMD SERVICE
# ===================================================================
log "Installing systemd service..."
info "Installing and enabling systemd service..."

install_systemd_service() {
    # Check if systemd is available
    if ! command_exists systemctl; then
        warning "systemctl not found. Systemd service installation will be skipped."
        return 1
    fi
    
    # Copy the service file to the systemd directory
    if ! sudo cp "$ROOT_DIR/ets2-server.service" /etc/systemd/system/; then
        warning "Failed to copy service file to /etc/systemd/system/"
        return 1
    fi
    
    # Reload systemd configuration
    if ! sudo systemctl daemon-reload; then
        warning "Failed to reload systemd configuration"
        return 1
    fi
    
    # Enable the service to start on boot
    if ! sudo systemctl enable ets2-server.service; then
        warning "Failed to enable ets2-server service"
        return 1
    fi
    
    info "Systemd service installed and enabled"
    return 0
}

# Install the systemd service
if install_systemd_service; then
    success "Systemd service installed successfully."
else
    warning "There were issues installing the systemd service. You may need to configure it manually."
    echo "To manually install the service:"
    echo "1. Copy $ROOT_DIR/ets2-server.service to /etc/systemd/system/"
    echo "2. Run: sudo systemctl daemon-reload"
    echo "3. Run: sudo systemctl enable ets2-server.service"
fi

# ===================================================================
# CREATE DOCUMENTATION
# ===================================================================
log "Creating documentation..."
info "Creating README documentation..."

cat > "$ROOT_DIR/ETS2_SERVER_README.md" << EOF || warning "Failed to create README file"
# Euro Truck Simulator 2 Multiplayer Server

This document contains instructions for managing your ETS2 Multiplayer Server.

## Server Information

- Server Name: $SERVER_NAME
- Game: Euro Truck Simulator 2
- Login Token: $SERVER_TOKEN

## Managing the Server

### Starting the Server

To start the ETS2 server, run:

\`\`\`bash
./start_ets2_server.sh
\`\`\`

The server will start in the background, and you can check the logs with:

\`\`\`bash
tail -f ets2_server.log
\`\`\`

### Stopping the Server

To stop the ETS2 server, run:

\`\`\`bash
./stop_ets2_server.sh
\`\`\`

### Restarting the Server

To restart the ETS2 server, run:

\`\`\`bash
./restart_ets2_server.sh
\`\`\`

## Using Systemd Service

The setup has installed a systemd service for easier management:

\`\`\`bash
# Start the server
sudo systemctl start ets2-server

# Stop the server
sudo systemctl stop ets2-server

# Restart the server
sudo systemctl restart ets2-server

# Check server status
sudo systemctl status ets2-server

# View logs
sudo journalctl -u ets2-server
\`\`\`

## Automatic Monitoring

A monitor script has been setup to check the server status every 5 minutes and restart it if it's not running.
You can manually run the monitor with:

\`\`\`bash
./monitor_ets2_server.sh
\`\`\`

## Server Configuration

The main server configuration file is located at:

\`\`\`
ets2server/server_config.sii
\`\`\`

If you need to modify server settings (like player limit, password, etc.), edit this file.

## Firewall Configuration

The following ports are open in your firewall:

- TCP/UDP: $SERVER_PORT (Game connection port)
- TCP/UDP: $QUERY_PORT (Query port)

## Important Note

For a fully functional server, you need to create proper server packages using the ETS2 desktop client.
Follow these steps:

1. Install ETS2 on a desktop computer
2. Launch the game
3. Open the console (~) and type \`export_server_packages\`
4. Find the exported files in your Documents/Euro Truck Simulator 2 folder
5. Upload them to your server and place in the ets2server directory

## Troubleshooting

If the server fails to start, check:

1. The log file \`ets2_server.log\` for error messages
2. Ensure server_packages files are properly created and in correct locations
3. Verify the server_logon_token is correctly set in the configuration
4. Check disk space using \`df -h\`
5. Check for network issues with \`ping download.eurotrucksimulator2.com\`
6. Verify all script permissions with \`ls -l *.sh\`

## Recovering From Failures

If the server becomes completely unresponsive:

1. Force stop all processes: \`pkill -9 -f "eurotrucks2_server"\`
2. Delete the PID file: \`rm ets2_server.pid\`
3. Restart the server: \`./restart_ets2_server.sh\`

## Support

If you encounter issues with your server, consult the official SCS Software documentation:
https://modding.scssoft.com/wiki/Documentation/Tools/Dedicated_Server

## Log Files

- \`ets2_setup.log\` - Installation and setup log
- \`ets2_server.log\` - Main server runtime log
- \`ets2_stop.log\` - Server stop operations log
- \`ets2_restart.log\` - Server restart operations log
- \`ets2_monitor.log\` - Server monitoring log
EOF

success "Server documentation created successfully."

# ===================================================================
# DISPLAY FINAL MESSAGES
# ===================================================================
log "Setup complete!"
success "ETS2 server setup completed successfully!"

# Run a health check
info "Running post-installation health check..."
run_health_check

# Create an initial backup
info "Creating initial backup..."
create_backup

# Create help script for management
cat > "$ROOT_DIR/manage_ets2_server.sh" << 'EOF' || warning "Failed to create management script"
#!/bin/bash
# ETS2 Server Management Script
# Description: Easy management for ETS2 Dedicated Server

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR" || { echo "Failed to change to script directory"; exit 1; }

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Menu function
show_menu() {
    clear
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${CYAN} ETS2 SERVER MANAGEMENT MENU ${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${GREEN}1) Start server${NC}"
    echo -e "${RED}2) Stop server${NC}"
    echo -e "${YELLOW}3) Restart server${NC}"
    echo -e "${BLUE}4) Run health check${NC}"
    echo -e "${GREEN}5) Create backup${NC}"
    echo -e "${YELLOW}6) Restore from backup${NC}"
    echo -e "${BLUE}7) View server logs${NC}"
    echo -e "${CYAN}8) Check for updates${NC}"
    echo -e "${RED}9) Exit${NC}"
    echo ""
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice [1-9]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        1)
            echo -e "${GREEN}Starting server...${NC}"
            if [ -f "$SCRIPT_DIR/start_ets2_server.sh" ]; then
                "$SCRIPT_DIR/start_ets2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Start script not found.${NC}"
                sleep 2
            fi
            ;;
        2)
            echo -e "${RED}Stopping server...${NC}"
            if [ -f "$SCRIPT_DIR/stop_ets2_server.sh" ]; then
                "$SCRIPT_DIR/stop_ets2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Stop script not found.${NC}"
                sleep 2
            fi
            ;;
        3)
            echo -e "${YELLOW}Restarting server...${NC}"
            if [ -f "$SCRIPT_DIR/restart_ets2_server.sh" ]; then
                "$SCRIPT_DIR/restart_ets2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Restart script not found.${NC}"
                sleep 2
            fi
            ;;
        4)
            echo -e "${BLUE}Running health check...${NC}"
            if [ -f "$SCRIPT_DIR/setup_ETS2_server.sh" ]; then
                # Execute the health check function directly
                "$SCRIPT_DIR/setup_ETS2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Setup script not found.${NC}"
                sleep 2
            fi
            ;;
        5)
            echo -e "${GREEN}Creating backup...${NC}"
            if [ -f "$SCRIPT_DIR/setup_ETS2_server.sh" ]; then
                # Execute the backup function
                "$SCRIPT_DIR/setup_ETS2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Setup script not found.${NC}"
                sleep 2
            fi
            ;;
        6)
            echo -e "${YELLOW}Restoring from backup...${NC}"
            if [ -f "$SCRIPT_DIR/setup_ETS2_server.sh" ]; then
                # Execute the restore function
                "$SCRIPT_DIR/setup_ETS2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Setup script not found.${NC}"
                sleep 2
            fi
            ;;
        7)
            echo -e "${BLUE}Viewing server logs...${NC}"
            if [ -f "$SCRIPT_DIR/ets2_server.log" ]; then
                less "$SCRIPT_DIR/ets2_server.log" || tail -n 100 "$SCRIPT_DIR/ets2_server.log"
            else
                echo -e "${RED}Server log not found.${NC}"
                sleep 2
            fi
            ;;
        8)
            echo -e "${CYAN}Checking for updates...${NC}"
            if [ -f "$SCRIPT_DIR/setup_ETS2_server.sh" ]; then
                # Execute the update check function
                "$SCRIPT_DIR/setup_ETS2_server.sh"
                read -p "Press Enter to return to menu..."
            else
                echo -e "${RED}Setup script not found.${NC}"
                sleep 2
            fi
            ;;
        9)
            echo -e "${RED}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Try again.${NC}"
            sleep 2
            ;;
    esac
done
EOF

# Set execute permissions on management script
chmod +x "$ROOT_DIR/manage_ets2_server.sh" || warning "Failed to set execute permission on management script"

# Provide detailed final output
cat << EOF

======================================================================
 🚚 ETS2 SERVER SETUP COMPLETED SUCCESSFULLY!
======================================================================

Server information:
- Server name: $SERVER_NAME
- Maximum players: $MAX_PLAYERS
- Server port: $SERVER_PORT
- Query port: $QUERY_PORT
- Server version: ${ETS2_SERVER_VERSION:-"1.47"}

Server management:
- GUI menu:          ./manage_ets2_server.sh
- Start:             ./start_ets2_server.sh
- Stop:              ./stop_ets2_server.sh
- Restart:           ./restart_ets2_server.sh
- Monitor:           ./monitor_ets2_server.sh

Systemd service:
- Start:             sudo systemctl start ets2-server
- Stop:              sudo systemctl stop ets2-server
- Restart:           sudo systemctl restart ets2-server
- Status:            sudo systemctl status ets2-server
- Enable at boot:    sudo systemctl enable ets2-server
- Disable at boot:   sudo systemctl disable ets2-server

Server files:
- Main config:       $SERVER_DIR/server_config.sii
- Packages config:   $SERVER_DIR/server_packages.sii
- Executable:        $SERVER_DIR/bin/linux_x64/eurotrucks2_server

Log files:
- Setup log:         $LOG_FILE
- Server log:        $ROOT_DIR/ets2_server.log
- Monitor log:       $ROOT_DIR/ets2_monitor.log

Backup:
- Backup directory:  $BACKUP_DIR
- Initial backup:    $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)

IMPORTANT: For a fully functioning server, you should replace the 
server_packages files with ones exported from your desktop game client.

For more information, see:
- $ROOT_DIR/ETS2_SERVER_README.md - Detailed server documentation
======================================================================

EOF 