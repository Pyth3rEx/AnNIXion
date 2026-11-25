{
  # Tunnel classification piggybacks on annixion-vpn-tunnels (system/vpn/cli/tunnels.nix)
  # instead of re-guessing interface types here — same source of truth the VPN
  # killswitch and the shell banner (home/shell/default.nix's annixion-tunnels) use.
  "custom/network-info" = {
    exec = ''
      tunnels=""
      if command -v annixion-vpn-tunnels >/dev/null 2>&1; then
        tunnels=" $(annixion-vpn-tunnels 2>/dev/null | tr '\n' ' ') "
      fi

      addr_rows=$(ip -4 addr show scope global 2>/dev/null | awk -v tunnels="$tunnels" '
        /inet/ {
          cidr = $2
          split($NF, a, "@")
          iface = a[length(a)]
          type = "LAN"
          if (index(tunnels, " " iface " ")) {
            type = "VPN"
            # Several providers (Mullvad, ProtonVPN, …) name WireGuard
            # interfaces <country>-<city>-wg-<n>, e.g. ie-dub-wg-102 — same
            # naming assumption the shell banner comment notes (home/shell/default.nix).
            if (match(iface, /^[a-z][a-z]-/))
              type = "VPN(" toupper(substr(iface, 1, 2)) ")"
          }
          else if (iface ~ /^wl/) type = "WiFi"
          else if (iface ~ /^(docker|br-|veth|virbr)/) type = "Docker"
          else if (iface ~ /^tailscale/) type = "Tailscale"
          print type "\t" cidr "\t" iface
        }
      ')

      proxy_rows=""
      for p in http_proxy https_proxy all_proxy; do
        eval "val=\$$p"
        if [ -n "$val" ]; then
          host=$(printf '%s' "$val" | sed -E 's#^[a-zA-Z]+://##; s#/+$##')
          proxy_rows="$proxy_rows$(printf 'Proxy\t%s\n' "$host")"
        fi
      done

      count=$(printf '%s\n' "$addr_rows" | grep -c .)

      # on-click (below) bumps this file so repeated clicks cycle the pill's
      # displayed address; idx 0 (no clicks yet, or a stale/garbage file)
      # falls back to the old smart-default pick.
      idx_file="$XDG_RUNTIME_DIR/waybar-network-info-idx"
      idx=$(cat "$idx_file" 2>/dev/null)
      if [ -z "$idx" ]; then
        idx=0
      else
        case "$idx" in
          *[!0-9]*) idx=0 ;;
        esac
      fi

      if [ "$idx" -eq 0 ] || [ "$count" -eq 0 ]; then
        # Prefer the address on the default route's interface over "first in
        # the list" — same idea as fastfetch's route module (home/apps/fastfetch.nix).
        default_iface=$(ip -4 route show default 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") { print $(i+1); exit }}')
        local_ip=$(printf '%s\n' "$addr_rows" | awk -F'\t' -v want="$default_iface" '$3==want{print $2; exit}' | cut -d/ -f1)
        [ -z "$local_ip" ] && local_ip=$(printf '%s\n' "$addr_rows" | awk -F'\t' '$1!~/^VPN/{print $2; exit}' | cut -d/ -f1)
        [ -z "$local_ip" ] && local_ip=$(printf '%s\n' "$addr_rows" | awk -F'\t' '{print $2; exit}' | cut -d/ -f1)
      else
        sel=$(( (idx - 1) % count ))
        local_ip=$(printf '%s\n' "$addr_rows" | awk -F'\t' -v want="$sel" 'NR-1==want{print $2; exit}' | cut -d/ -f1)
      fi

      tooltip=$(printf '%s%s' "$addr_rows" "$proxy_rows" | awk -F'\t' 'NF>=2{printf "%s / %s\n", $1, $2}')

      jq -nc --arg text "$count · $local_ip" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
    '';
    format = "󰑩 {}";
    return-type = "json";
    interval = 30;
    signal = 9;
    on-click = ''
      idx_file="$XDG_RUNTIME_DIR/waybar-network-info-idx"
      idx=$(cat "$idx_file" 2>/dev/null)
      if [ -z "$idx" ]; then
        idx=0
      else
        case "$idx" in
          *[!0-9]*) idx=0 ;;
        esac
      fi
      echo $((idx + 1)) > "$idx_file" 2>/dev/null
      pkill -RTMIN+9 waybar
    '';
    on-click-right = "nm-connection-editor";
  };
}
