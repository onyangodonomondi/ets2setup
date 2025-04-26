# 🚚 ETS2 Dedicated Server Setup Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive bash script for automating the setup and configuration of a Euro Truck Simulator 2 dedicated multiplayer server on Linux. Built with robust error handling and failsafe mechanisms.

![Euro Truck Simulator 2](https://img.shields.io/badge/ETS2-Dedicated_Server-blue)

## 📋 Features

- **One-command setup** - Automatically installs and configures everything needed
- **Complete server management** - Start, stop, restart, and monitoring scripts
- **Systemd integration** - Run your server as a system service
- **Auto-recovery** - Monitors server status and restarts if crashed
- **Robust error handling** - Comprehensive error checking and recovery mechanisms
- **Network retry logic** - Handles temporary network issues during downloads
- **Firewall configuration** - Automatically sets up required firewall rules
- **User management** - Creates a dedicated user when run as root
- **Detailed documentation** - Comprehensive usage instructions
- **Self-healing capability** - Automatically recovers from common failure scenarios

## 🔧 Requirements

- Linux server (Ubuntu/Debian recommended)
- Sudo access
- Internet connection for downloading server files
- At least 1GB of free disk space
- Required packages: curl, unzip, sudo, ufw, systemctl (installed automatically)

## 🚀 Quick Start

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

4. Start your server:
```bash
./start_ets2_server.sh
```

## 🧑‍💻 User Management

When run as root, the script will:

1. Prompt to create a dedicated user for running the server
2. Offer options to:
   - Generate a random secure password
   - Set a password manually (with a 1-minute timeout)
3. Add the user to the sudo group
4. Copy the setup script to the new user's home directory
5. Provide instructions to continue installation as the new user

This ensures the server runs with proper permissions and follows security best practices.

## 💪 Robustness Features

The script includes numerous failsafe mechanisms for a reliable setup:

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

The setup script creates several configuration files:

- `ets2server/server_config.sii` - Main server configuration
- `ets2server/server_packages.sii` - Server packages information
- `ets2-server.service` - Systemd service configuration

You can customize these files to change various server settings such as:
- Server name and description
- Maximum player count
- Game settings (traffic, damage, etc.)
- Network settings

## 📊 Server Management

### Starting the Server

```bash
./start_ets2_server.sh
```

The server will run in the background. You can check the logs with:
```bash
tail -f ets2_server.log
```

### Stopping the Server

```bash
./stop_ets2_server.sh
```

### Restarting the Server

```bash
./restart_ets2_server.sh
```

### Using Systemd Service

```bash
# Start the server
sudo systemctl start ets2-server

# Stop the server
sudo systemctl stop ets2-server

# Check status
sudo systemctl status ets2-server

# Enable auto-start on boot
sudo systemctl enable ets2-server
```

### Monitoring

The script installs a monitoring service that checks if the server is running every 5 minutes and restarts it if needed. You can also manually check the server status:

```bash
./monitor_ets2_server.sh
```

## 🔥 Firewall Configuration

The script automatically opens the required ports in the firewall:
- TCP/UDP: 27015 (Game connection port)
- TCP/UDP: 27016 (Query port)

## 📝 Troubleshooting

If the server fails to start, check:

1. The log files in the installation directory:
   - `ets2_setup.log` - Installation logs
   - `ets2_server.log` - Server runtime logs
   - `ets2_restart.log` - Restart operation logs
   - `ets2_monitor.log` - Monitoring logs

2. Common issues:
   - Ensure server_packages files are properly created
   - Verify the server_logon_token is correctly set
   - Check available disk space with `df -h`
   - Verify network connectivity

3. Recovery:
   - Force stop: `pkill -9 -f "eurotrucks2_server"`
   - Remove PID: `rm ets2_server.pid`
   - Restart: `./restart_ets2_server.sh`

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