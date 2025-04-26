# ETS2 Server Setup Script - Cross-Platform Edition

This package provides a complete setup solution for Euro Truck Simulator 2 dedicated servers on both Windows and Linux platforms.

## Overview

The ETS2 Server Setup Script automates the full installation and configuration of an Euro Truck Simulator 2 dedicated server, with robust error handling, platform detection, and proper recovery mechanisms. This cross-platform version supports both Linux and Windows operating systems.

## Features

- **Cross-platform support** - Works on both Linux and Windows servers
- **Automatic platform detection** - Detects OS and uses appropriate commands
- **User-friendly setup** - Guided installation process with clear instructions
- **Robust error handling** - Comprehensive error detection and recovery
- **Server management scripts** - Easy-to-use scripts for starting, stopping, and monitoring the server
- **Firewall configuration** - Automatic setup of required firewall rules (UFW on Linux, Windows Firewall on Windows)
- **Backup and restore** - Automatic backup creation and restore capabilities

## Requirements

### Linux
- Bash shell
- curl, unzip, sudo commands
- UFW (recommended for firewall management)
- Systemd (for service management)

### Windows
- Windows 10 or Windows Server 2016 or newer
- PowerShell 5.0 or higher
- Administrator privileges (for firewall configuration)

## Installation

### Linux Installation

1. Download the setup script:
   ```bash
   wget https://example.com/setup_ETS2_server.sh
   ```

2. Make it executable:
   ```bash
   chmod +x setup_ETS2_server.sh
   ```

3. Run the script:
   ```bash
   ./setup_ETS2_server.sh [YOUR_STEAM_TOKEN]
   ```

### Windows Installation

1. Download the PowerShell script:
   ```
   setup_ETS2_server.ps1
   ```

   Alternatively, you can generate the Windows script from Linux:
   ```bash
   ./setup_ETS2_server.sh --generate-windows-script
   ```

2. Open PowerShell as Administrator and navigate to the script directory.

3. Allow script execution if needed:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

4. Run the script:
   ```powershell
   .\setup_ETS2_server.ps1 -SERVER_TOKEN "YOUR_STEAM_TOKEN"
   ```

## Server Management

### Linux Commands

- Start server: `./start_ets2_server.sh`
- Stop server: `./stop_ets2_server.sh`
- Restart server: `./restart_ets2_server.sh`
- Monitor server: `./monitor_ets2_server.sh`

You can also use systemd commands:
```bash
sudo systemctl start ets2-server
sudo systemctl stop ets2-server
sudo systemctl restart ets2-server
sudo systemctl status ets2-server
```

### Windows Commands

- Start server: Double-click `start_ets2_server.bat` or run in command prompt
- Stop server: Double-click `stop_ets2_server.bat`
- Restart server: Double-click `restart_ets2_server.bat`

## Configuration

The main server configuration file is located at:
- Linux: `ets2server/server_config.sii`
- Windows: `ets2server\server_config.sii`

You can edit this file to modify server settings like player limit, password, etc.

## Mod Management

This package includes specialized scripts for toggling mods on and off without editing configuration files manually:

### Windows Mod Management

Use the PowerShell script to enable or disable mods:

```powershell
# Enable mods
.\toggle_mods.ps1 -Enable

# Disable mods
.\toggle_mods.ps1
```

### Linux Mod Management

Use the Bash script with various options:

```bash
# Enable mods
./toggle_mods.sh enable

# Disable mods
./toggle_mods.sh disable

# Toggle between enabled/disabled state
./toggle_mods.sh
```

Both scripts automatically create a backup of your configuration before making changes. Remember to restart your server after toggling mods for changes to take effect.

## Important Note

For a fully functional server, you need to create proper server packages using the ETS2 desktop client:

1. Install ETS2 on a desktop computer
2. Launch the game
3. Open the console (~) and type `export_server_packages`
4. Find the exported files in your Documents/Euro Truck Simulator 2 folder
5. Upload them to your server and place in the ets2server directory

## Troubleshooting

If the server fails to start, check:

1. The log file (`ets2_server.log`) for error messages
2. Ensure server_packages files are properly created and in correct locations
3. Verify the server_logon_token is correctly set in the configuration
4. Check disk space
5. Verify network connectivity
6. Ensure appropriate permissions are set on all executables

## Platform-Specific Issues

### Linux
- If encountering permission issues, verify the script has execute permissions: `chmod +x *.sh`
- For firewall issues, check UFW status: `sudo ufw status`

### Windows
- Run PowerShell as Administrator for firewall configuration
- If Windows Firewall blocks the server, check the inbound rules in Windows Firewall settings
- For script execution issues, ensure your execution policy allows running scripts: `Get-ExecutionPolicy`

## Support

If you encounter issues with your server, consult the official SCS Software documentation:
https://modding.scssoft.com/wiki/Documentation/Tools/Dedicated_Server 