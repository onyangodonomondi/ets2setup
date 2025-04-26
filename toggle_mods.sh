#!/bin/bash
# toggle_mods.sh - Toggle ETS2 server mods on/off
# Usage: 
#   ./toggle_mods.sh enable    # To enable mods
#   ./toggle_mods.sh disable   # To disable mods
#   ./toggle_mods.sh           # To toggle between enabled/disabled

CONFIG_FILE="ets2server/server_config.sii"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\e[31mError: Could not find server config at $CONFIG_FILE\e[0m"
    exit 1
fi

# Create backup of current config
cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
echo "Created backup at $CONFIG_FILE.bak"

# Check current mods status
CURRENT_STATUS=$(grep -o "mods_optioning: \(true\|false\)" "$CONFIG_FILE" | cut -d' ' -f2)

if [ "$1" = "enable" ] || ([ -z "$1" ] && [ "$CURRENT_STATUS" = "false" ]); then
    # Enable mods
    sed -i 's/mods_optioning: false/mods_optioning: true/g' "$CONFIG_FILE"
    echo -e "\e[32mMods have been ENABLED for the ETS2 server\e[0m"
elif [ "$1" = "disable" ] || ([ -z "$1" ] && [ "$CURRENT_STATUS" = "true" ]); then
    # Disable mods
    sed -i 's/mods_optioning: true/mods_optioning: false/g' "$CONFIG_FILE"
    echo -e "\e[33mMods have been DISABLED for the ETS2 server\e[0m"
else
    echo -e "\e[33mInvalid argument. Use 'enable', 'disable', or no argument to toggle.\e[0m"
    exit 1
fi

echo "Server configuration updated. Restart the server for changes to take effect." 