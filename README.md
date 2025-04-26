# 🚚 ETS2 Dedicated Server Setup Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive bash script for automating the setup and configuration of a Euro Truck Simulator 2 dedicated multiplayer server on Linux.

![Euro Truck Simulator 2](https://img.shields.io/badge/ETS2-Dedicated_Server-blue)

## 📋 Features

- **One-command setup** - Automatically installs and configures everything needed
- **Complete server management** - Start, stop, restart, and monitoring scripts
- **Systemd integration** - Run your server as a system service
- **Auto-recovery** - Monitors server status and restarts if crashed
- **Firewall configuration** - Automatically sets up required firewall rules
- **Detailed documentation** - Comprehensive usage instructions

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

### Monitoring

The script installs a monitoring service that checks if the server is running every 5 minutes and restarts it if needed.

## 🔥 Firewall Configuration

The script automatically opens the required ports in the firewall:
- TCP/UDP: 27015 (Game connection port)
- TCP/UDP: 27016 (Query port)

## ⚠️ Important Notes

For a fully functional server, you need to replace the placeholder server packages with real ones:

1. Install ETS2 on a desktop computer
2. Launch the game
3. Open the console (~) and type `export_server_packages`
4. Find the exported files in your Documents/Euro Truck Simulator 2 folder
5. Upload them to your server and place in the ets2server directory

## 📝 Troubleshooting

If the server fails to start, check:

1. The log file `ets2_server.log` for error messages
2. Ensure server_packages files are properly created and in correct locations
3. Verify the server_logon_token is correctly set in the configuration

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/yourusername/ets2-server-setup/issues).

## 📜 License

This project is [MIT](LICENSE) licensed.

## 📚 Resources

- [Official ETS2 Dedicated Server Documentation](https://modding.scssoft.com/wiki/Documentation/Tools/Dedicated_Server)
- [SCS Forums](https://forum.scssoft.com/) 