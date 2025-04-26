# 🚚 ETS2 Dedicated Server Setup Script (Cross-Platform)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive setup solution for automating the installation and configuration of a Euro Truck Simulator 2 dedicated multiplayer server on both Linux and Windows platforms. Built with robust error handling and failsafe mechanisms.

![Euro Truck Simulator 2](https://img.shields.io/badge/ETS2-Dedicated_Server-blue)

## 📋 Features

- **Cross-platform support** - Works on both Linux and Windows servers
- **One-command setup** - Automatically installs and configures everything needed
- **Complete server management** - Start, stop, restart, and monitoring scripts
- **Systemd integration** - Run your server as a system service (Linux)
- **Auto-recovery** - Monitors server status and restarts if crashed
- **Robust error handling** - Comprehensive error checking and recovery mechanisms
- **Network retry logic** - Handles temporary network issues during downloads
- **Firewall configuration** - Automatically sets up required firewall rules (UFW on Linux, Windows Firewall on Windows)
- **User management** - Creates a dedicated user when run as root (Linux)
- **Detailed documentation** - Comprehensive usage instructions
- **Self-healing capability** - Automatically recovers from common failure scenarios
- **Mod management** - Toggle mods on/off with simple commands

## 🔧 Requirements

### Linux
- Linux server (Ubuntu/Debian recommended)
- Sudo access
- Bash shell
- Required packages: curl, unzip, sudo, ufw, systemctl (installed automatically)

### Windows
- Windows 10 or Windows Server 2016 or newer
- PowerShell 5.0 or higher
- Administrator privileges (for firewall configuration)

Both platforms require:
- Internet connection for downloading server files
- At least 1GB of free disk space

## 🚀 Quick Start

### Linux Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/ets2-server-setup.git
cd ets2-server-setup
```

2. Make the script executable:
```bash
chmod +x setup_ETS2_server.sh
```

3. Run the setup script:
```bash
./setup_ETS2_server.sh [YOUR_SERVER_TOKEN]
```
If you don't specify a server token, a default one will be used.

### Windows Installation

1. Download the PowerShell script or generate it from Linux:
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
.\setup_ETS2_server.ps1 -SERVER_TOKEN "YOUR_SERVER_TOKEN"
```

## 🧑‍💻 User Management (Linux)

When run as root on Linux, the script will:

1. Prompt to create a dedicated user for running the server
2. Offer options to:
   - Generate a random secure password
   - Set a password manually (with a 1-minute timeout)
3. Add the user to the sudo group
4. Copy the setup script to the new user's home directory
5. Provide instructions to continue installation as the new user

This ensures the server runs with proper permissions and follows security best practices.

## 💪 Robustness Features

The scripts include numerous failsafe mechanisms for a reliable setup:

- **Comprehensive error handling** - Every critical operation is checked for success
- **Automatic dependency installation** - Missing packages are automatically installed
- **Disk space validation** - Ensures sufficient space before downloading large files
- **Network retry logic** - Auto-retries downloads on network interruptions
- **Fallback mechanisms** - Alternative approaches if primary methods fail
- **Self-healing capabilities** - Automatically fixes common issues
- **Detailed logging** - Complete logs for easy troubleshooting
- **Safe script termination** - Properly cleans up on unexpected exit
- **Process verification** - Checks that server processes are running correctly

## ⚙️ Configuration

The setup scripts create several configuration files:

- Linux: `ets2server/server_config.sii` - Main server configuration
- Windows: `ets2server\server_config.sii` - Main server configuration
- `server_packages.sii` - Server packages information
- Linux: `ets2-server.service` - Systemd service configuration (Linux only)

You can customize these files to change various server settings such as:
- Server name and description
- Maximum player count
- Game settings (traffic, damage, etc.)
- Network settings

## 🔄 Mod Management

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

## 📊 Server Management

### Linux Commands

```bash
# Start the server
./start_ets2_server.sh

# Stop the server
./stop_ets2_server.sh

# Restart the server
./restart_ets2_server.sh

# Monitor the server
./monitor_ets2_server.sh
```

You can also use systemd commands on Linux:
```bash
sudo systemctl start ets2-server
sudo systemctl stop ets2-server
sudo systemctl restart ets2-server
sudo systemctl status ets2-server
sudo systemctl enable ets2-server  # Enable auto-start on boot
```

### Windows Commands

- Start server: Double-click `start_ets2_server.bat` or run in command prompt
- Stop server: Double-click `stop_ets2_server.bat`
- Restart server: Double-click `restart_ets2_server.bat`

### Checking Logs

On Linux, view logs with:
```bash
tail -f ets2_server.log
```

On Windows, check the log files in the installation directory.

## 🔥 Firewall Configuration

The scripts automatically open the required ports in the firewall:
- TCP/UDP: 27015 (Game connection port)
- TCP/UDP: 27016 (Query port)

On Linux, UFW is used for firewall configuration.
On Windows, Windows Firewall rules are created automatically.

## 📝 Troubleshooting

If the server fails to start, check:

1. The log files in the installation directory:
   - `ets2_setup.log` - Installation logs
   - `ets2_server.log` - Server runtime logs
   - `ets2_restart.log` - Restart operation logs
   - `ets2_monitor.log` - Monitoring logs (Linux only)

2. Common issues:
   - Ensure server_packages files are properly created
   - Verify the server_logon_token is correctly set
   - Check available disk space
   - Verify network connectivity
   - Ensure appropriate permissions are set on all executables

### Platform-Specific Issues

#### Linux
- If encountering permission issues, verify the script has execute permissions: `chmod +x *.sh`
- For firewall issues, check UFW status: `sudo ufw status`
- Recovery: `pkill -9 -f "eurotrucks2_server"`, `rm ets2_server.pid`, `./restart_ets2_server.sh`

#### Windows
- Run PowerShell as Administrator for firewall configuration
- If Windows Firewall blocks the server, check the inbound rules in Windows Firewall settings
- For script execution issues, ensure your execution policy allows running scripts: `Get-ExecutionPolicy`

## ⚠️ Important Notes

For a fully functional server, you need to replace the placeholder server packages with real ones:

1. Install ETS2 on a desktop computer
2. Launch the game
3. Open the console (~) and type `export_server_packages`
4. Find the exported files in your Documents/Euro Truck Simulator 2 folder
5. Upload them to your server and place in the ets2server directory

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yourusername/ets2-server-setup/issues).

## 📜 License

This project is [MIT](LICENSE) licensed.

## 📚 Resources

- [Official ETS2 Dedicated Server Documentation](https://modding.scssoft.com/wiki/Documentation/Tools/Dedicated_Server)
- [SCS Forums](https://forum.scssoft.com/) 