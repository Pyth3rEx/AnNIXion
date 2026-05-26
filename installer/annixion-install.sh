#!/usr/bin/env bash
# AnNIXion TUI Installer
# Interactive setup wizard for deploying AnNIXion on NixOS

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source shared functions
source "${SCRIPT_DIR}/lib/common.sh"

# State variables
DISK=""
HOSTNAME=""
USERNAME=""
PASSWORD=""
TIMEZONE=""
ENCRYPTION_PASSPHRASE=""
PROFILES=()  # Array of selected profiles: redteam, osint, privacy

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

###############################################################################
# UI Functions
###############################################################################

show_title() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                      AnNIXion Installer                        ║
║         Declarative Offensive Security on NixOS                ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_welcome() {
    show_title
    whiptail --title "Welcome" --msgbox \
        "Welcome to the AnNIXion installer!\n\n\
This wizard will guide you through:\n\
  • Disk selection and partitioning\n\
  • Full disk encryption (LUKS2 + Btrfs)\n\
  • System configuration (hostname, user, timezone)\n\
  • Tool profile selection (RedTeam, OSINT, Privacy)\n\n\
The process is non-destructive up until the final confirmation step.\n\n\
Press OK to begin." \
        16 70
}

show_error() {
    local message="$1"
    whiptail --title "Error" --msgbox "${message}" 10 70
}

show_success() {
    local message="$1"
    whiptail --title "Success" --msgbox "${message}" 10 70
}

show_info() {
    local message="$1"
    whiptail --title "Information" --msgbox "${message}" 10 70
}

###############################################################################
# Disk Selection
###############################################################################

select_disk() {
    show_title
    echo -e "${YELLOW}Scanning for disks...${NC}"
    
    # Find all block devices (excluding partitions)
    local disks=()
    while IFS= read -r line; do
        disks+=("$line")
    done < <(lsblk -dln -o NAME,SIZE,MODEL 2>/dev/null | grep -v loop || true)
    
    if [[ ${#disks[@]} -eq 0 ]]; then
        show_error "No disks found. Please check your hardware configuration."
        return 1
    fi
    
    # Build whiptail menu
    local menu_items=()
    local index=0
    while IFS= read -r disk_info; do
        menu_items+=("$index" "$disk_info")
        ((index++))
    done < <(printf '%s\n' "${disks[@]}")
    
    local selection
    selection=$(whiptail --title "Select Disk" --menu \
        "Select the disk to install AnNIXion on.\n\n⚠️  WARNING: The entire disk will be erased!\n\n" \
        20 80 ${#disks[@]} \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3) || return 1
    
    # Extract disk name from selection
    DISK="/dev/$(echo "${disks[$selection]}" | awk '{print $1}')"
    
    # Confirm disk selection
    local disk_info
    disk_info=$(lsblk -dln "$DISK" 2>/dev/null | awk '{print $1, $2, $3}')
    
    if whiptail --title "Confirm Disk Selection" --yesno \
        "You have selected:\n\n  $disk_info\n\n⚠️  This disk will be completely erased!\n\nProceed?" \
        12 70; then
        return 0
    else
        return 1
    fi
}

###############################################################################
# Hostname Configuration
###############################################################################

generate_random_hostname() {
    # Generate random hostname in Windows style: DESKTOP-XXXXXX or LAPTOP-XXXXXX
    local prefix
    if (( RANDOM % 2 )); then
        prefix="DESKTOP"
    else
        prefix="LAPTOP"
    fi
    
    # Generate 6 random alphanumeric characters (uppercase)
    local random_suffix
    random_suffix=$(head -c 3 /dev/urandom | base64 | tr -d '=+/' | tr '[:lower:]' '[:upper:]' | cut -c1-6)
    
    echo "${prefix}-${random_suffix}"
}

select_hostname() {
    show_title
    
    local default_hostname
    default_hostname=$(generate_random_hostname)
    
    local hostname
    hostname=$(whiptail --title "Hostname" --inputbox \
        "Enter a hostname for this system.\n\n(Default: $default_hostname)" \
        12 70 "$default_hostname" \
        3>&1 1>&2 2>&3) || return 1
    
    # Validate hostname
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        show_error "Invalid hostname. Use only alphanumeric characters and hyphens.\nMust start and end with alphanumeric characters."
        return 1
    fi
    
    HOSTNAME="$hostname"
    return 0
}

###############################################################################
# User Configuration
###############################################################################

select_username() {
    show_title
    
    local username
    username=$(whiptail --title "Username" --inputbox \
        "Enter the primary non-root username.\n\n(Recommended: operator or your preferred name)" \
        12 70 "operator" \
        3>&1 1>&2 2>&3) || return 1
    
    # Validate username
    if [[ ! "$username" =~ ^[a-z_]([a-z0-9_-]{0,31})?$ ]]; then
        show_error "Invalid username. Use lowercase letters, numbers, underscores, and hyphens.\nMust start with a letter or underscore."
        return 1
    fi
    
    USERNAME="$username"
    return 0
}

select_password() {
    show_title
    
    local pass1 pass2
    
    while true; do
        pass1=$(whiptail --title "User Password" --passwordbox \
            "Enter password for user '$USERNAME'" \
            12 70 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ -z "$pass1" ]]; then
            show_error "Password cannot be empty."
            continue
        fi
        
        if [[ ${#pass1} -lt 8 ]]; then
            show_error "Password must be at least 8 characters long."
            continue
        fi
        
        pass2=$(whiptail --title "Confirm Password" --passwordbox \
            "Confirm password for user '$USERNAME'" \
            12 70 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ "$pass1" == "$pass2" ]]; then
            PASSWORD="$pass1"
            return 0
        else
            show_error "Passwords do not match."
        fi
    done
}

###############################################################################
# Encryption Configuration
###############################################################################

select_encryption_passphrase() {
    show_title
    
    local pass1 pass2
    
    while true; do
        pass1=$(whiptail --title "Disk Encryption Passphrase" --passwordbox \
            "Enter LUKS2 encryption passphrase for disk $DISK\n\n\
This passphrase protects your entire encrypted disk.\n\
You will be prompted to enter it every time you boot." \
            16 70 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ -z "$pass1" ]]; then
            show_error "Passphrase cannot be empty."
            continue
        fi
        
        if [[ ${#pass1} -lt 8 ]]; then
            show_error "Passphrase must be at least 8 characters long."
            continue
        fi
        
        pass2=$(whiptail --title "Confirm Passphrase" --passwordbox \
            "Confirm LUKS2 encryption passphrase" \
            12 70 \
            3>&1 1>&2 2>&3) || return 1
        
        if [[ "$pass1" == "$pass2" ]]; then
            ENCRYPTION_PASSPHRASE="$pass1"
            return 0
        else
            show_error "Passphrases do not match."
        fi
    done
}

###############################################################################
# Timezone Selection
###############################################################################

select_timezone() {
    show_title
    
    # Use a reasonable default timezone list
    local timezones=(
        "0" "UTC"
        "1" "America/New_York"
        "2" "America/Los_Angeles"
        "3" "America/Chicago"
        "4" "Europe/London"
        "5" "Europe/Paris"
        "6" "Europe/Berlin"
        "7" "Asia/Tokyo"
        "8" "Asia/Shanghai"
        "9" "Australia/Sydney"
    )
    
    local selection
    selection=$(whiptail --title "Select Timezone" --menu \
        "Select your timezone:" \
        20 70 10 \
        "${timezones[@]}" \
        3>&1 1>&2 2>&3) || return 1
    
    TIMEZONE="${timezones[$((selection * 2 + 1))]}"
    return 0
}

###############################################################################
# Profile Selection
###############################################################################

select_profiles() {
    show_title
    
    local checklist_items=(
        "redteam" "Penetration Testing & Offensive Tools" "off"
        "osint" "Open Source Intelligence Tools" "off"
        "privacy" "Privacy & Anonymization Tools" "off"
    )
    
    local selected
    selected=$(whiptail --title "Select Tool Profiles" --checklist \
        "Choose which tool profiles to install.\n\n\
• RedTeam: nmap, metasploit, burpsuite, sqlmap, etc.\n\
• OSINT: theHarvester, spiderfoot, maltego, etc.\n\
• Privacy: Tor, Mullvad, proxychains, MAC randomization, etc.\n\n\
You can select multiple profiles." \
        20 80 3 \
        "${checklist_items[@]}" \
        3>&1 1>&2 2>&3) || return 1
    
    # Parse selected profiles
    PROFILES=()
    for profile in redteam osint privacy; do
        if echo "$selected" | grep -q "\"$profile\""; then
            PROFILES+=("$profile")
        fi
    done
    
    if [[ ${#PROFILES[@]} -eq 0 ]]; then
        show_error "You must select at least one profile."
        return 1
    fi
    
    return 0
}

###############################################################################
# Summary and Confirmation
###############################################################################

show_summary() {
    show_title
    
    local profiles_str
    profiles_str=$(printf '%s, ' "${PROFILES[@]}")
    profiles_str="${profiles_str%, }"
    
    local summary
    summary="Installation Summary\n\n\
Disk: $DISK\n\
Hostname: $HOSTNAME\n\
Username: $USERNAME\n\
Timezone: $TIMEZONE\n\
Profiles: $profiles_str\n\n\
⚠️  This will erase all data on $DISK and install AnNIXion.\n\
This action cannot be undone."
    
    if whiptail --title "Review Configuration" --yesno "$summary" 18 70; then
        return 0
    else
        return 1
    fi
}

###############################################################################
# Installation Steps (stub for now)
###############################################################################

run_installation() {
    show_title
    
    {
        echo "10"
        echo "# Partitioning disk..."
        sleep 2
        
        echo "30"
        echo "# Creating encrypted filesystem..."
        sleep 2
        
        echo "50"
        echo "# Generating NixOS configuration..."
        sleep 2
        
        echo "70"
        echo "# Installing NixOS..."
        sleep 2
        
        echo "90"
        echo "# Finalizing installation..."
        sleep 1
        
        echo "100"
        echo "# Installation complete!"
        
    } | whiptail --gauge "Installing AnNIXion..." 8 70 0
}

###############################################################################
# Main Flow
###############################################################################

main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "This installer must be run as root."
        exit 1
    fi
    
    # Check for whiptail
    if ! command -v whiptail &> /dev/null; then
        echo "whiptail is required but not installed. Aborting."
        exit 1
    fi
    
    # Interactive wizard flow
    show_welcome || exit 0
    
    while ! select_disk; do
        if ! whiptail --title "Retry" --yesno "Try disk selection again?" 8 70; then
            exit 1
        fi
    done
    
    while ! select_hostname; do
        if ! whiptail --title "Retry" --yesno "Try hostname selection again?" 8 70; then
            exit 1
        fi
    done
    
    while ! select_username; do
        if ! whiptail --title "Retry" --yesno "Try username selection again?" 8 70; then
            exit 1
        fi
    done
    
    while ! select_password; do
        if ! whiptail --title "Retry" --yesno "Try password selection again?" 8 70; then
            exit 1
        fi
    done
    
    while ! select_encryption_passphrase; do
        if ! whiptail --title "Retry" --yesno "Try passphrase selection again?" 8 70; then
            exit 1
        fi
    done
    
    while ! select_timezone; do
        if ! whiptail --title "Retry" --yesno "Try timezone selection again?" 8 70; then
            exit 1
        fi
    done
    
    while ! select_profiles; do
        if ! whiptail --title "Retry" --yesno "Try profile selection again?" 8 70; then
            exit 1
        fi
    done
    
    # Final review
    while ! show_summary; do
        if ! whiptail --title "Modify" --yesno "Return to main menu?" 8 70; then
            exit 1
        fi
    done
    
    # Run installation
    run_installation
    
    whiptail --title "Complete" --msgbox "AnNIXion installation complete!\n\nThe system will reboot now." 10 70
    reboot
}

# Run main unless sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
