{
  # player defaults to "playerctld" (services.playerctld, enabled in
  # default.nix), which always follows whichever MPRIS player last changed
  # state — no per-app wiring needed to track Spotify vs. a browser tab.
  mpris = {
    format = "{player_icon} {dynamic}";
    format-paused = "{status_icon} {dynamic}";
    player-icons = {
      default = "󰝚";
      spotify = "󰓇";
    };
    status-icons = {
      playing = "󰐊";
      paused = "󰏤";
    };
    title-len = 24;
    artist-len = 16;
    album-len = 0;
    max-length = 32;
    tooltip-format = "{player} — {dynamic}";
  };
}
