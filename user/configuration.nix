# user/configuration.nix
# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM-LEVEL OVERRIDES
#
# Put your personal system settings here. This file is imported by flake.nix
# AFTER all base modules, so anything you write here wins automatically.
#
# You do NOT need lib.mkForce. Every option in the base modules uses
# lib.mkDefault (priority 1000). Your options here have normal priority (100),
# which is higher — they win without any special wrapper.
#
# ── What belongs here ────────────────────────────────────────────────────────
#   • Your hostname, timezone, locale
#   • Extra users or groups
#   • Extra system packages you want installed globally
#   • Swapping out or disabling base features (e.g. disable openssh)
#   • Any NixOS option from the manual: https://nixos.org/manual/nixos/stable/options
#
# ── What does NOT belong here ────────────────────────────────────────────────
#   • Your dotfiles, shell config, personal apps → those go in user/home.nix
#   • hardware-configuration.nix settings → edit that file directly
#
# ── Example overrides ────────────────────────────────────────────────────────
#
#   # Change hostname
#   networking.hostName = "my-machine";
#
#   # Change timezone
#   time.timeZone = "America/New_York";
#
#   # Add a package system-wide
#   environment.systemPackages = with pkgs; [ docker ];
#
#   # Add yourself to docker group
#   users.users.operator.extraGroups = [ "wheel" "networkmanager" "docker" ];
#
#   # Disable SSH if you don't need the fallback
#   services.openssh.enable = false;
#
# ─────────────────────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

{
  # Your overrides go here.
}
