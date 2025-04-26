#!/bin/bash
# ===================================================================
# ETS2 Server Complete Setup Script
# ===================================================================
# Description: Automates the full installation and configuration of an Euro Truck Simulator 2 dedicated server
# Author: Unknown
# Usage: ./setup_ets2_server.sh [STEAM_TOKEN]
# Version: 1.1
# ===================================================================

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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    fi
    
    # Only exit directly when it's an unexpected error
    # This allows normal exits to proceed
    if [ $err -ne 0 ] && [ $err -ne 99 ]; then
        exit $err
    fi
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
        if command_exists apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y "$package"
        elif command_exists yum; then
            sudo yum install -y "$package"
        elif command_exists dnf; then
            sudo dnf install -y "$package"
        else
            error_exit "Cannot install '$package'. No supported package manager found." $E_DEPENDENCY
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
info "Beginning ETS2 server setup process"

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
# INSTALL DEPENDENCIES
# ===================================================================
log "Installing required packages..."
info "Updating package lists and installing dependencies..."

# We use a function here to catch errors and provide better messages
install_dependencies() {
    sudo apt update || {
        warning "Failed to update package lists. Continuing anyway..."
        return 1
    }
    
    sudo apt install -y curl unzip net-tools ufw || {
        warning "Failed to install some packages. Will try individual installation..."
        
        # Try installing packages one by one
        for pkg in curl unzip net-tools ufw; do
            info "Installing $pkg..."
            sudo apt install -y "$pkg" || warning "Failed to install $pkg"
        done
    }
    
    # Verify critical packages
    for pkg in curl unzip; do
        if ! command_exists "$pkg"; then
            error_exit "Critical package $pkg could not be installed." $E_DEPENDENCY
        fi
    done
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
    
    SERVER_PACK_URL="https://download.eurotrucksimulator2.com/server_pack_1.47.zip"
    PACK_FILE="$ROOT_DIR/ets2_server_pack.zip"
    
    # Try to download with retries
    safe_download "$SERVER_PACK_URL" "$PACK_FILE"
else
    info "Server pack already downloaded. Skipping download."
    
    # Verify the existing file is valid
    if ! unzip -t "$ROOT_DIR/ets2_server_pack.zip" &>/dev/null; then
        warning "The existing ZIP file appears to be corrupt. Re-downloading..."
        mv "$ROOT_DIR/ets2_server_pack.zip" "$ROOT_DIR/ets2_server_pack.zip.bak"
        safe_download "https://download.eurotrucksimulator2.com/server_pack_1.47.zip" "$ROOT_DIR/ets2_server_pack.zip"
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