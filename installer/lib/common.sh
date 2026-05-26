#!/usr/bin/env bash
# AnNIXion Installer Shared Functions Library
# Common utilities for disk partitioning, encryption, and NixOS installation

set -euo pipefail

###############################################################################
# Logging Functions
###############################################################################

log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[✓] $*" >&2
}

###############################################################################
# Disk Partitioning and Encryption
###############################################################################

# Partition disk with EFI boot and LUKS2-encrypted root
# Usage: partition_and_encrypt_disk /dev/sdX
partition_and_encrypt_disk() {
    local disk="$1"
    local encrypt_pass="${2:-}"
    
    log_info "Partitioning $disk..."
    
    # Wipe disk
    if command -v wipefs &> /dev/null; then
        wipefs -a "$disk" || true
    fi
    
    # Create partition table (GPT)
    parted -s "$disk" mklabel gpt || {
        log_error "Failed to create GPT partition table"
        return 1
    }
    
    # Create EFI partition (500MB)
    parted -s "$disk" mkpart primary fat32 0% 512MB || {
        log_error "Failed to create EFI partition"
        return 1
    }
    parted -s "$disk" set 1 esp on || {
        log_error "Failed to mark EFI partition"
        return 1
    }
    
    # Create root partition (remaining space)
    parted -s "$disk" mkpart primary 512MB 100% || {
        log_error "Failed to create root partition"
        return 1
    }
    
    log_success "Partitions created"
    
    # Format EFI partition
    local efi_part
    efi_part="${disk}1"
    if [[ "$disk" == *nvme* ]] || [[ "$disk" == *mmcblk* ]]; then
        efi_part="${disk}p1"
    fi
    
    mkfs.fat -F 32 "$efi_part" || {
        log_error "Failed to format EFI partition"
        return 1
    }
    
    log_success "EFI partition formatted"
    
    # Encrypt root partition
    local root_part
    root_part="${disk}2"
    if [[ "$disk" == *nvme* ]] || [[ "$disk" == *mmcblk* ]]; then
        root_part="${disk}p2"
    fi
    
    if [[ -z "$encrypt_pass" ]]; then
        log_error "Encryption passphrase required"
        return 1
    fi
    
    echo -n "$encrypt_pass" | cryptsetup luksFormat --type luks2 "$root_part" - || {
        log_error "Failed to create LUKS2 encryption"
        return 1
    }
    
    log_success "LUKS2 encryption created"
    
    # Open encrypted partition
    echo -n "$encrypt_pass" | cryptsetup luksOpen "$root_part" nixos-root - || {
        log_error "Failed to open encrypted partition"
        return 1
    }
    
    log_success "Encrypted partition opened"
    
    # Create Btrfs filesystem
    mkfs.btrfs /dev/mapper/nixos-root || {
        log_error "Failed to create Btrfs filesystem"
        return 1
    }
    
    log_success "Btrfs filesystem created"
    
    return 0
}

###############################################################################
# Filesystem Mounting
###############################################################################

# Mount filesystems for NixOS installation
# Assumes partitions are encrypted and ready
mount_filesystems() {
    log_info "Mounting filesystems..."
    
    local efi_part="/dev/sda1"  # Will be set properly by caller
    local root_mount="/mnt"
    local efi_mount="/mnt/boot"
    
    # Create mount points
    mkdir -p "$root_mount" "$efi_mount" || {
        log_error "Failed to create mount points"
        return 1
    }
    
    # Mount root
    mount /dev/mapper/nixos-root "$root_mount" || {
        log_error "Failed to mount root filesystem"
        return 1
    }
    
    log_success "Root filesystem mounted"
    
    # Mount EFI
    mount "$efi_part" "$efi_mount" || {
        log_error "Failed to mount EFI partition"
        return 1
    }
    
    log_success "EFI partition mounted"
    
    return 0
}

###############################################################################
# NixOS Configuration Generation
###############################################################################

# Generate NixOS configuration for installation
# Usage: generate_nixos_config
generate_nixos_config() {
    log_info "Generating NixOS configuration..."
    
    local config_file="/mnt/etc/nixos/configuration.nix"
    local hardware_file="/mnt/etc/nixos/hardware-configuration.nix"
    
    # Generate hardware configuration
    nixos-generate-config --root /mnt || {
        log_error "Failed to generate hardware configuration"
        return 1
    }
    
    log_success "Hardware configuration generated"
    
    # Verify configuration was created
    if [[ ! -f "$hardware_file" ]]; then
        log_error "Hardware configuration file not created"
        return 1
    fi
    
    log_success "NixOS configuration ready"
    
    return 0
}

###############################################################################
# NixOS Installation
###############################################################################

# Run nixos-install to complete the installation
# Usage: run_nixos_install
run_nixos_install() {
    log_info "Running nixos-install..."
    
    nixos-install --root /mnt --no-root-password || {
        log_error "nixos-install failed"
        return 1
    }
    
    log_success "NixOS installation complete"
    
    return 0
}

###############################################################################
# Post-Installation Cleanup
###############################################################################

# Cleanup after installation
# Usage: post_install_cleanup
post_install_cleanup() {
    log_info "Running post-installation cleanup..."
    
    # Unmount filesystems
    umount -R /mnt || {
        log_error "Failed to unmount filesystems"
        return 1
    }
    
    log_success "Filesystems unmounted"
    
    # Close encrypted partition
    cryptsetup luksClose nixos-root || {
        log_error "Failed to close encrypted partition"
        return 1
    }
    
    log_success "Encrypted partition closed"
    
    return 0
}

###############################################################################
# Validation Functions
###############################################################################

# Validate disk is available and writable
# Usage: validate_disk /dev/sdX
validate_disk() {
    local disk="$1"
    
    if [[ ! -b "$disk" ]]; then
        log_error "Disk $disk not found or not a block device"
        return 1
    fi
    
    if [[ ! -w "$disk" ]]; then
        log_error "Disk $disk is not writable (run as root?)"
        return 1
    fi
    
    return 0
}

# Validate hostname format
# Usage: validate_hostname "hostname"
validate_hostname() {
    local hostname="$1"
    
    # Allow alphanumeric and hyphens, must start/end with alphanumeric
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        log_error "Invalid hostname: $hostname"
        return 1
    fi
    
    return 0
}

# Validate username format
# Usage: validate_username "username"
validate_username() {
    local username="$1"
    
    # Linux username rules: lowercase letters, digits, underscore, hyphen
    # Must start with letter or underscore, max 32 chars
    if [[ ! "$username" =~ ^[a-z_]([a-z0-9_-]{0,31})?$ ]]; then
        log_error "Invalid username: $username"
        return 1
    fi
    
    return 0
}

# Validate timezone
# Usage: validate_timezone "America/New_York"
validate_timezone() {
    local timezone="$1"
    
    if [[ ! -f "/usr/share/zoneinfo/$timezone" ]]; then
        log_error "Invalid timezone: $timezone"
        return 1
    fi
    
    return 0
}

# Check if required tools are available
# Usage: check_required_tools whiptail cryptsetup parted
check_required_tools() {
    local missing_tools=()
    
    for tool in "$@"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

###############################################################################
# Export functions for sourcing
###############################################################################

export -f log_info log_error log_success
export -f partition_and_encrypt_disk mount_filesystems
export -f generate_nixos_config run_nixos_install post_install_cleanup
export -f validate_disk validate_hostname validate_username validate_timezone
export -f check_required_tools
