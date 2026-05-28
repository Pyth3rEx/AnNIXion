# AnNIXion Installer — Development Guide

This guide covers developing, testing, and debugging the TUI installer.

## Building the ISO

Build a bootable ISO with the installer:

```bash
nix build .#nixosConfigurations.annixion-iso.config.system.build.isoImage
```

The ISO will be available at:

```
./result/iso/annixion-*.iso
```

### Quick Build on NixOS

```bash
# Build the ISO
cd /path/to/AnNIXion
nix build .#annixion-iso

# Result is symlinked to ./result
ls -lh result/iso/
```

## Testing the Installer

### VM Testing (Recommended)

#### Using QEMU

```bash
# Build ISO
nix build .#annixion-iso

# Create a test disk image (10GB)
qemu-img create -f qcow2 test-disk.qcow2 10G

# Boot ISO with qemu
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -smp 2 \
  -cdrom ./result/iso/annixion-*.iso \
  -hda test-disk.qcow2 \
  -net nic,model=virtio \
  -net user
```

Then run the installer:

```bash
annixion-install
```

#### Using VirtualBox

1. Create a new VM with 2GB RAM, 20GB disk
2. Mount the ISO as the boot device
3. Boot and run `annixion-install`

#### Using Hyper-V (Windows)

```powershell
# Create a Generation 2 VM
New-VM -Name "AnNIXion-Test" `
  -MemoryStartupBytes 2GB `
  -NewVHDPath "C:\VMs\annixion-test.vhdx" `
  -NewVHDSizeBytes 20GB `
  -Generation 2

# Add ISO
Set-VMDvdDrive -VMName "AnNIXion-Test" `
  -Path "path\to\annixion.iso"

# Boot and connect
Start-VM -Name "AnNIXion-Test"
vmconnect localhost "AnNIXion-Test"
```

### Physical Hardware Testing

1. Write ISO to USB:
   ```bash
   sudo dd if=./result/iso/annixion-*.iso of=/dev/sdX bs=4M status=progress
   sudo sync
   ```

2. Boot from USB on target machine

3. Run installer:
   ```bash
   annixion-install
   ```

## Debugging

### Viewing Installer Logs

During installation, logs are written to stderr. To capture them:

```bash
annixion-install 2>&1 | tee /tmp/installer.log
```

### Manual Installation for Debugging

If the installer fails, you can manually run steps:

```bash
# Open the shared functions library
bash
source /usr/local/lib/annixion/common.sh

# Test functions individually
log_info "Testing logging"
validate_disk /dev/sda
validate_hostname "test-host"
```

### Entering a Shell

If the installer hangs or crashes, press `Ctrl+C` and enter a shell:

```bash
bash
```

All installer functions and tools are available.

### Common Issues

#### "whiptail: command not found"

The installer module didn't load properly. Verify it's enabled in `iso-configuration.nix`:

```nix
annixion.installer.enable = true;
```

#### Disk selection shows no devices

1. Check if `lsblk` works:
   ```bash
   lsblk
   ```

2. Verify disks are visible:
   ```bash
   ls -la /dev/sd* /dev/nvme* /dev/mmcblk* 2>/dev/null
   ```

#### Encryption fails

1. Check `cryptsetup` is available:
   ```bash
   cryptsetup --version
   ```

2. Verify entropy:
   ```bash
   cat /proc/sys/kernel/random/entropy_avail
   ```
   Should be > 1000. If low, the system needs more entropy.

#### NixOS installation fails

1. Check network connectivity:
   ```bash
   ping 8.8.8.8
   ```

2. Verify mounts are correct:
   ```bash
   mount | grep /mnt
   ```

3. Check disk space:
   ```bash
   df -h /mnt
   ```

## Development Workflow

### Making Changes to the Installer

1. Edit the installer script:
   ```bash
   $EDITOR installer/annixion-install.sh
   ```

2. Edit shared functions:
   ```bash
   $EDITOR installer/lib/common.sh
   ```

3. Rebuild and test:
   ```bash
   nix build .#annixion-iso
   # Test in VM
   ```

### Adding New Steps

1. Define validation function in `installer/lib/common.sh`:
   ```bash
   validate_something() {
       local value="$1"
       # validation logic
       return 0 or 1
   }
   ```

2. Define selection function in `installer/annixion-install.sh`:
   ```bash
   select_something() {
       show_title
       local result
       result=$(whiptail --title "Something" --inputbox \
           "Prompt text" 12 70 "default" \
           3>&1 1>&2 2>&3) || return 1
       
       if ! validate_something "$result"; then
           show_error "Invalid input"
           return 1
       fi
       
       SOMETHING="$result"
       return 0
   }
   ```

3. Add to main flow:
   ```bash
   while ! select_something; do
       if ! whiptail --yesno "Try again?" 8 70; then
           exit 1
       fi
   done
   ```

4. Test with ISO rebuild

### Testing Individual Functions

Create a test script:

```bash
#!/usr/bin/env bash
source installer/lib/common.sh

# Test specific function
validate_hostname "DESKTOP-ABC123"
echo $?  # 0 = valid, 1 = invalid

validate_username "operator"
echo $?
```

Run on live ISO or NixOS:

```bash
bash test.sh
```

## Continuous Integration

### Local Pre-commit Checks

```bash
#!/bin/bash
# Verify shell scripts
shellcheck installer/annixion-install.sh installer/lib/common.sh

# Build test
nix build .#annixion-iso 2>&1 | head -20
```

## Performance Optimization

### ISO Size

Current minimal installer ISO is ~700MB. To reduce:

1. Remove unnecessary packages from `modules/installer.nix`
2. Compress more aggressively
3. Use brotli instead of xz for packages

### Installation Time

Timing breakdown:
- Partitioning: ~1-2 seconds
- Encryption setup: ~5-10 seconds
- Filesystem creation: ~2-5 seconds
- NixOS install: ~3-10 minutes (depends on system speed and network)

## Release Checklist

Before releasing a new installer version:

- [ ] All scripts pass shellcheck
- [ ] ISO builds without warnings
- [ ] Tested on at least 2 VM hypervisors
- [ ] Tested on bare metal hardware
- [ ] All validation functions tested
- [ ] Documentation is current
- [ ] Version number updated in ROADMAP.md
- [ ] Commit message follows convention
- [ ] Tagged release in git

## Further Reading

- [NixOS Installation Guide](https://nixos.org/manual/nixos/stable/#sec-installation)
- [NixOS ISO Building](https://nixos.org/manual/nixos/stable/#sec-building-iso)
- [Whiptail Documentation](https://pagure.io/newt/blob/master/README)
- [cryptsetup Manual](https://man7.org/linux/man-pages/man8/cryptsetup.8.html)
- [Btrfs Wiki](https://btrfs.wiki.kernel.org/)
