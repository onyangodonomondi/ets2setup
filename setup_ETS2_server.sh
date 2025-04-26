#!/bin/bash
# ===================================================================
# ETS2 Server Complete Setup Script
# ===================================================================
# Description: Automates the full installation and configuration of an Euro Truck Simulator 2 dedicated server
# Author: Unknown
# Usage: ./setup_ets2_server.sh [STEAM_TOKEN]
# Version: 1.0
# ===================================================================

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

# ===================================================================
# DIRECTORY SETUP
# ===================================================================
# Root directory - uses current directory as base
ROOT_DIR=$(pwd)
SERVER_DIR="$ROOT_DIR/ets2server"                     # Server installation directory
LOG_FILE="$ROOT_DIR/ets2_setup.log"                   # Setup log file

# ===================================================================
# LOGGING FUNCTION
# ===================================================================
log() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Create log file
> "$LOG_FILE"
log "Starting ETS2 server setup"

# ===================================================================
# PRELIMINARY CHECKS
# ===================================================================
# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then
    log "Please don't run this script as root. The script will use sudo when needed."
    exit 1
fi

# Check for required command-line tools
for cmd in curl unzip sudo ufw systemctl; do
    if ! command -v $cmd &> /dev/null; then
        log "Error: Required command '$cmd' not found. Please install it and try again."
        exit 1
    fi
done

# ===================================================================
# INSTALL DEPENDENCIES
# ===================================================================
log "Installing required packages..."
sudo apt update
sudo apt install -y curl unzip net-tools ufw

# ===================================================================
# CREATE DIRECTORY STRUCTURE
# ===================================================================
log "Creating directory structure..."
mkdir -p "$SERVER_DIR"
mkdir -p "$ROOT_DIR/.local/share/Euro Truck Simulator 2"
mkdir -p /home/server_packages

# ===================================================================
# DOWNLOAD & EXTRACT SERVER FILES
# ===================================================================
# Download ETS2 dedicated server (if not already present)
if [ ! -f "$ROOT_DIR/ets2_server_pack.zip" ]; then
    log "Downloading ETS2 dedicated server files..."
    curl -L -o "$ROOT_DIR/ets2_server_pack.zip" "https://download.eurotrucksimulator2.com/server_pack_1.47.zip"
fi

# Extract server files
log "Extracting server files..."
unzip -o "$ROOT_DIR/ets2_server_pack.zip" -d "$SERVER_DIR" 

# ===================================================================
# SET PERMISSIONS
# ===================================================================
log "Setting permissions..."
chmod -R 755 "$SERVER_DIR/bin"

# ===================================================================
# CREATE SERVER CONFIGURATION FILES
# ===================================================================
log "Creating server configuration..."
# Create the main server configuration file
cat > "$SERVER_DIR/server_config.sii" << EOF
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

# ===================================================================
# CREATE SERVER PACKAGES FILES (MINIMAL VERSION FOR TESTING)
# ===================================================================
log "Creating server packages files..."
# Create a minimal server_packages.sii file
cat > "$SERVER_DIR/server_packages.sii" << EOF
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
dd if=/dev/zero of="$SERVER_DIR/server_packages.dat" bs=1K count=10

# ===================================================================
# COPY SERVER PACKAGES TO ALL REQUIRED LOCATIONS
# ===================================================================
# The server checks multiple locations for these files
cp "$SERVER_DIR/server_packages.sii" "$ROOT_DIR/.local/share/Euro Truck Simulator 2/"
cp "$SERVER_DIR/server_packages.dat" "$ROOT_DIR/.local/share/Euro Truck Simulator 2/"
cp "$SERVER_DIR/server_packages.sii" "$SERVER_DIR/bin/linux_x64/"
cp "$SERVER_DIR/server_packages.dat" "$SERVER_DIR/bin/linux_x64/"

# ===================================================================
# CREATE SERVER MANAGEMENT SCRIPTS
# ===================================================================
log "Creating server management scripts..."

# ===================================================================
# 1. START SCRIPT - LAUNCHES THE SERVER
# ===================================================================
cat > "$ROOT_DIR/start_ets2_server.sh" << EOF
#!/bin/bash
# ETS2 Server Start Script
# Description: Starts the ETS2 dedicated server

# Set working directory to the server directory
cd "\$(dirname "\$0")/ets2server"

# Log file for server output
LOG_FILE="../ets2_server.log"

# Clear previous log
echo "Starting ETS2 server at \$(date)" > "\$LOG_FILE"

# Force cleanup any existing processes to avoid false detections
pkill -f "eurotrucks2_server" 2>/dev/null
if [ -f "../ets2_server.pid" ]; then
    rm ../ets2_server.pid
fi
sleep 1

# Copy server packages files to all possible locations
echo "Copying server packages files to all required locations..." >> "\$LOG_FILE"
mkdir -p ~/.local/share/Euro\\ Truck\\ Simulator\\ 2/
cp server_packages.* ~/.local/share/Euro\\ Truck\\ Simulator\\ 2/
cp server_packages.* ./bin/linux_x64/

# Make sure executable files have correct permissions
chmod +x bin/linux_x64/server_launch.sh
chmod +x bin/linux_x64/eurotrucks2_server

# Set the LD_LIBRARY_PATH correctly
export LD_LIBRARY_PATH="\$(pwd)/linux64:\$LD_LIBRARY_PATH"
echo "LD_LIBRARY_PATH set to: \$LD_LIBRARY_PATH" >> "\$LOG_FILE"

# Start the server
echo "Server will run in the background. Check logs with: tail -f \$LOG_FILE" | tee -a "\$LOG_FILE"

# Start server in background and redirect output to log file
cd bin/linux_x64
echo "Executing from directory: \$(pwd)" >> "\$LOG_FILE"
echo "Command: ./eurotrucks2_server" >> "\$LOG_FILE"

# Start server directly to avoid quoting issues in the launch script
nohup ./eurotrucks2_server >> "\$LOG_FILE" 2>&1 &

# Save PID to file for easier management
PID=\$!
echo \$PID > ../../../ets2_server.pid
echo "Server started with PID: \$PID" | tee -a "\$LOG_FILE"

# Check if process is running after 2 seconds
sleep 2
if ps -p \$PID > /dev/null; then
    echo "Server process is still running." >> "\$LOG_FILE"
else
    echo "WARNING: Server process has already terminated! Check logs for errors." | tee -a "\$LOG_FILE"
fi
EOF

# ===================================================================
# 2. STOP SCRIPT - GRACEFULLY SHUTS DOWN THE SERVER
# ===================================================================
cat > "$ROOT_DIR/stop_ets2_server.sh" << EOF
#!/bin/bash
# ETS2 Server Stop Script
# Description: Gracefully stops the ETS2 server

# Log file for tracking
LOG_FILE="ets2_stop.log"
echo "\$(date): Stopping ETS2 server" > "\$LOG_FILE"

# Get the PID from file if it exists
PID_FILE="ets2_server.pid"

if [ -f "\$PID_FILE" ]; then
    PID=\$(cat "\$PID_FILE")
    echo "Found PID file with PID: \$PID" >> "\$LOG_FILE"
    
    # Check if process is still running
    if ps -p \$PID > /dev/null; then
        echo "Stopping ETS2 server (PID: \$PID)..."
        kill \$PID >> "\$LOG_FILE" 2>&1
        
        # Wait for process to terminate
        count=0
        while ps -p \$PID > /dev/null && [ \$count -lt 10 ]; do
            echo "Waiting for server to shut down..."
            sleep 2
            count=\$((count+1))
        done
        
        # Force kill if still running
        if ps -p \$PID > /dev/null; then
            echo "Server not responding. Force stopping..." | tee -a "\$LOG_FILE"
            kill -9 \$PID >> "\$LOG_FILE" 2>&1
        fi
        
        echo "ETS2 server stopped."
    else
        echo "PID \$PID no longer exists. Cleaning up PID file." | tee -a "\$LOG_FILE"
    fi
    
    # Remove PID file
    rm "\$PID_FILE"
else
    echo "No PID file found. Trying to find the process." | tee -a "\$LOG_FILE"
    # Try to find any eurotrucks2_server process
    PID=\$(pgrep -f "eurotrucks2_server" | head -n 1)
    
    if [ -n "\$PID" ]; then
        echo "Found server with PID: \$PID" | tee -a "\$LOG_FILE"
        echo "Stopping ETS2 server (PID: \$PID)..."
        kill \$PID >> "\$LOG_FILE" 2>&1
        
        # Wait for process to terminate
        count=0
        while ps -p \$PID > /dev/null && [ \$count -lt 10 ]; do
            echo "Waiting for server to shut down..."
            sleep 2
            count=\$((count+1))
        done
        
        # Force kill if still running
        if ps -p \$PID > /dev/null; then
            echo "Server not responding. Force stopping..." | tee -a "\$LOG_FILE"
            kill -9 \$PID >> "\$LOG_FILE" 2>&1
        fi
        
        echo "ETS2 server stopped."
    else
        echo "No ETS2 server process found." | tee -a "\$LOG_FILE"
    fi
fi

# Kill any remaining eurotrucks2_server processes as a last resort
if pgrep -f "eurotrucks2_server" > /dev/null; then
    echo "Found additional server processes. Cleaning up..." | tee -a "\$LOG_FILE"
    pkill -f "eurotrucks2_server" >> "\$LOG_FILE" 2>&1
fi
EOF

# ===================================================================
# 3. RESTART SCRIPT - RESTARTS THE SERVER
# ===================================================================
cat > "$ROOT_DIR/restart_ets2_server.sh" << EOF
#!/bin/bash
# ETS2 Server Restart Script
# Description: Stops and then starts the ETS2 server 

echo "Restarting ETS2 server..."

# Get the directory of this script
SCRIPT_DIR="\$(dirname "\$(readlink -f "\$0")")"

# Stop the server if it's running
\$SCRIPT_DIR/stop_ets2_server.sh

# Wait a moment before starting again
sleep 5

# Start the server
\$SCRIPT_DIR/start_ets2_server.sh

echo "ETS2 server restart complete."
EOF

# ===================================================================
# 4. MONITOR SCRIPT - CHECKS SERVER STATUS AND RESTARTS IF NEEDED
# ===================================================================
cat > "$ROOT_DIR/monitor_ets2_server.sh" << EOF
#!/bin/bash
# ETS2 Server Monitor Script
# Description: Monitors server status and restarts if not running

# Get the directory of this script
SCRIPT_DIR="\$(dirname "\$(readlink -f "\$0")")"
LOG_FILE="\$SCRIPT_DIR/ets2_monitor.log"

check_server() {
    # Check if server process is running
    if ! pgrep -f "eurotrucks2_server" > /dev/null; then
        echo "[\$(date)] ETS2 server not running. Restarting..." | tee -a "\$LOG_FILE"
        \$SCRIPT_DIR/start_ets2_server.sh
        echo "[\$(date)] Restart attempt completed." | tee -a "\$LOG_FILE"
    else
        echo "[\$(date)] ETS2 server is running." >> "\$LOG_FILE"
    fi
}

# Run once when script is executed
check_server

# Setup cron job to run this script every 5 minutes if not already set
if ! crontab -l | grep -q "monitor_ets2_server.sh"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * \$SCRIPT_DIR/monitor_ets2_server.sh") | crontab -
    echo "Added monitor script to crontab. It will check server status every 5 minutes."
fi
EOF

# ===================================================================
# CREATE SYSTEMD SERVICE
# ===================================================================
log "Creating systemd service..."
cat > "$ROOT_DIR/ets2-server.service" << EOF
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

[Install]
WantedBy=multi-user.target
EOF

# ===================================================================
# SET EXECUTE PERMISSIONS ON SCRIPTS
# ===================================================================
log "Setting permissions on scripts..."
chmod +x "$ROOT_DIR/start_ets2_server.sh"
chmod +x "$ROOT_DIR/stop_ets2_server.sh"
chmod +x "$ROOT_DIR/restart_ets2_server.sh"
chmod +x "$ROOT_DIR/monitor_ets2_server.sh"

# ===================================================================
# CONFIGURE FIREWALL
# ===================================================================
log "Setting up firewall rules..."
sudo ufw allow 27015/tcp
sudo ufw allow 27015/udp
sudo ufw allow 27016/tcp
sudo ufw allow 27016/udp
# Make sure firewall is enabled
sudo ufw --force enable

# ===================================================================
# INSTALL SYSTEMD SERVICE
# ===================================================================
log "Installing systemd service..."
sudo cp "$ROOT_DIR/ets2-server.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ets2-server.service

# ===================================================================
# CREATE DOCUMENTATION
# ===================================================================
log "Creating documentation..."
cat > "$ROOT_DIR/ETS2_SERVER_README.md" << EOF
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

## Server Configuration

The main server configuration file is located at:

\`\`\`
ets2server/server_config.sii
\`\`\`

If you need to modify server settings (like player limit, password, etc.), edit this file.

## Firewall Configuration

The following ports are open in your firewall:

- TCP/UDP: 27015 (Game connection port)
- TCP/UDP: 27016 (Query port)

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

## Support

If you encounter issues with your server, consult the official SCS Software documentation:
https://modding.scssoft.com/wiki/Documentation/Tools/Dedicated_Server
EOF

# ===================================================================
# DISPLAY FINAL MESSAGES
# ===================================================================
log "Setup complete!"
log "To start the server, run: ./start_ets2_server.sh"
log "For more information, see the README file: ETS2_SERVER_README.md"
log "NOTE: For a full functioning server, you should replace the server_packages files with ones exported from your desktop game client"

echo ""
echo "======================================================================"
echo "ETS2 Server setup completed successfully!"
echo "Run './start_ets2_server.sh' to start the server"
echo "Check 'ETS2_SERVER_README.md' for more information"
echo "======================================================================" 