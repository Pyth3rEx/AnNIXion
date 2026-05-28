# AnNIXion Installer

TUI-based installer for automated AnNIXion deployment with full disk encryption, hostname generation, and profile selection.

## Features

- **Interactive TUI** — whiptail-based wizard with step-by-step guidance
- **Disk Selection** — scan and confirm target disk before installation
- **Full Disk Encryption** — LUKS2 + Btrfs with user-configured passphrase
- **Random Hostname Generation** — Windows-style hostnames (DESKTOP-XXXXXX, LAPTOP-XXXXXX)
- **User Configuration** — username, password, timezone setup
- **Profile Selection** — choose RedTeam, OSINT, Privacy, or combinations
- **Error Handling** — rollback on failure with clear error messages
- **Validation** — input validation for all user entries

## Usage

```bash
# Run installer from live ISO
sudo annixion-install
```

The installer will walk through:
1. Welcome and overview
2. Disk selection with confirmation
3. Hostname configuration (with random default)
4. Username and password setup
5. Encryption passphrase
6. Timezone selection
7. Tool profile selection
8. Installation summary and confirmation
9. Automated installation and reboot

## Requirements

The installer requires the following tools:
- `whiptail` — TUI dialogs
- `cryptsetup` — LUKS2 encryption
- `parted` — disk partitioning
- `mkfs.btrfs` — filesystem creation
- `nixos-generate-config` — hardware detection
- `nixos-install` — NixOS installation

All tools are included in the NixOS live environment.

## Architecture

### Directory Structure

```
installer/
├── annixion-install.sh   # Main installer script
├── lib/
│   └── common.sh         # Shared functions library
└── README.md             # This file
```

### Script Organization

- **Main script** (`annixion-install.sh`) handles:
  - TUI flow and user interaction
  - Input validation and error handling
  - Step navigation and retry logic
  - Configuration summary and confirmation

- **Shared library** (`lib/common.sh`) provides:
  - Disk partitioning and LUKS2 encryption
  - Filesystem mounting and unmounting
  - NixOS configuration generation
  - Installation execution
  - Post-installation cleanup
  - Validation functions
  - Logging utilities

## Configuration Collection

The installer collects the following configuration:

| Item | Purpose | Default | Validation |
|------|---------|---------|------------|
| **Disk** | Target installation disk | — | Must exist, writable, confirmed |
| **Hostname** | System hostname | DESKTOP/LAPTOP-XXXXXX | RFC 952 format |
| **Username** | Primary non-root user | operator | Linux username rules |
| **Password** | User password | — | Minimum 8 characters, confirmed |
| **Encryption Passphrase** | LUKS2 disk passphrase | — | Minimum 8 characters, confirmed |
| **Timezone** | System timezone | UTC | Valid zoneinfo entry |
| **Profiles** | Tool profiles | — | At least one selected |

## Installation Steps

1. **Disk Partitioning**
   - Wipe disk and create GPT partition table
   - Create 512MB FAT32 EFI partition
   - Create root partition with remaining space

2. **Encryption**
   - Set up LUKS2 on root partition
   - Open encrypted partition as `/dev/mapper/nixos-root`
   - Create Btrfs filesystem

3. **Filesystem Mounting**
   - Mount Btrfs root to `/mnt`
   - Mount FAT32 EFI to `/mnt/boot`

4. **NixOS Configuration**
   - Generate hardware configuration via `nixos-generate-config`
   - (Future: Generate flake configuration based on profiles)

5. **NixOS Installation**
   - Run `nixos-install --root /mnt --no-root-password`
   - Set up bootloader

6. **Post-Installation**
   - Unmount filesystems
   - Close encrypted partition
   - Prepare for reboot

## Error Handling

The installer handles errors gracefully:
- **Validation errors** — user is prompted to retry with corrections
- **Disk operations** — detailed error messages guide troubleshooting
- **Encryption failures** — rollback and retry
- **Installation failures** — abort with instructions for manual recovery

## Development

### Testing the installer

Test in a VM before deployment:

```bash
# On live ISO or NixOS system
sudo bash installer/annixion-install.sh
```

### Adding validation

Add new validation functions to `lib/common.sh`:

```bash
validate_something() {
    local value="$1"
    if [[ ! valid ]]; then
        log_error "Invalid something"
        return 1
    fi
    return 0
}
```

### Extending the installer

Add new steps to the main flow:

```bash
select_something() {
    # Get user input via whiptail
    # Validate input
    # Store in global variable
    return 0  # or 1 on cancel
}

# In main():
while ! select_something; do
    if ! whiptail --yesno "Try again?" 8 70; then
        exit 1
    fi
done
```

## Future Enhancements

- [ ] Disko integration for declarative partition layout
- [ ] Flake configuration generation based on profile selection
- [ ] Network configuration during installation
- [ ] RAID and LVM support
- [ ] Raid-1 and btrfs mirror configurations
- [ ] Pre-installation sanity checks
- [ ] Installation progress with real-time logs
- [ ] Rollback on installation failure

## Troubleshooting

### Installer exits unexpectedly

Check if required tools are available:

```bash
which whiptail cryptsetup parted mkfs.btrfs nixos-generate-config nixos-install
```

### Disk partitioning fails

Ensure:
- You have sufficient permissions (run as root)
- Target disk is not in use
- Disk has at least 10GB free space

### Encryption fails

Ensure:
- `cryptsetup` is properly installed
- `/dev/mapper` is available
- You have sufficient entropy (check `cat /proc/sys/kernel/random/entropy_avail`)

### NixOS installation fails

Check:
- `/mnt` is properly mounted
- Boot disk has at least 2GB free space
- Network connectivity for downloading packages

## License

See repository root LICENSE file.
