# The prompt. Segment layout and colours are documented in docs/zsh.md.
_:

{
  # The space inside each trailing diamond is the gap between segments.
  programs.oh-my-posh = {
    enable = true;

    settings = {
      "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
      version = 3;
      final_space = true;
      console_title_template = "{{ .Shell }} :: {{ .Folder }}";

      blocks = [
        # ── Line 1 — left ─────────────────────────────────────────────────
        {
          type = "prompt";
          alignment = "left";
          newline = true;
          segments = [
            # User @ host — flips to neon red when root.
            {
              type = "session";
              style = "diamond";
              leading_diamond = "<transparent,#252525></>";
              trailing_diamond = " ";
              foreground = "#ffffff";
              background = "#252525";
              foreground_templates = [ "{{ if .Root }}#000000{{ end }}" ];
              background_templates = [ "{{ if .Root }}#ff0033{{ end }}" ];
              template = "   {{ if .Root }}☠  ROOT{{ else }}{{ .UserName }}{{ end }}   {{ .HostName }}   ";
              properties.display_host = true;
            }
            # Path
            {
              type = "path";
              style = "diamond";
              leading_diamond = "<transparent,#181818></>";
              trailing_diamond = " ";
              foreground = "#d4d4d4";
              background = "#181818";
              template = "   {{ .Path }}   ";
              properties = {
                style = "agnoster_short";
                max_depth = 4;
                home_icon = "~";
                folder_separator_icon = "<transparent>  </>";
              };
            }
            # Git — branch · staged(●) · working(+) · ahead(↑) · behind(↓) ·
            # stash(⚑). Muted red when clean, neon red on any change.
            {
              type = "git";
              style = "diamond";
              leading_diamond = "<transparent,#0e0e0e></>";
              trailing_diamond = " ";
              foreground = "#cc1122";
              background = "#0e0e0e";
              foreground_templates = [
                "{{ if or .Working.Changed .Staging.Changed }}#ff0033{{ end }}"
              ];
              template = "⎇ {{ .HEAD }}{{ if .Staging.Changed }}  ●{{ add .Staging.Added .Staging.Modified .Staging.Deleted }}{{ end }}{{ if .Working.Changed }}  +{{ add .Working.Added .Working.Modified .Working.Deleted .Working.Untracked }}{{ end }}{{ if gt .Ahead 0 }}  ↑{{ .Ahead }}{{ end }}{{ if gt .Behind 0 }}  ↓{{ .Behind }}{{ end }}{{ if gt .StashCount 0 }}  ⚑{{ .StashCount }}{{ end }}   ";
              properties = {
                branch_icon = "";
                fetch_status = true;
                fetch_stash_count = true;
              };
            }
          ];
        }

        # ── Line 1 — right ────────────────────────────────────────────────
        # Right-to-left for powerline; clock anchors the edge.
        {
          type = "prompt";
          alignment = "right";
          segments = [
            # Clock — always visible; anchors far right
            {
              type = "time";
              style = "diamond";
              leading_diamond = "";
              trailing_diamond = " ";
              foreground = "#cc1122";
              background = "#2d2d2d";
              template = ''{{ .CurrentDate | date "15:04:05" }}   '';
            }
            # Exit code — only when non-zero
            {
              type = "exit";
              style = "diamond";
              leading_diamond = "";
              trailing_diamond = " ";
              foreground = "#ff0033";
              background = "#1e1e1e";
              template = "   ✗ {{ .Code }}   ";
              properties.always_enabled = false;
            }
            # Execution time — only when last command ran > 3 s
            {
              type = "executiontime";
              style = "diamond";
              leading_diamond = "";
              trailing_diamond = " ";
              foreground = "#ff1a1a";
              background = "#151515";
              template = "   ⏱ {{ .FormattedMs }}   ";
              properties = {
                threshold = 3000;
                style = "round";
                always_enabled = false;
              };
            }
            # Command char count — hidden until first command runs
            {
              type = "text";
              style = "diamond";
              leading_diamond = "";
              foreground = "#555555";
              background = "#0e0e0e";
              template = "{{ if .Env.OMP_CMD_LEN }}   {{ .Env.OMP_CMD_LEN }}c   {{ end }}";
            }
          ];
        }

        # ── Line 2 — prompt character ─────────────────────────────────────
        {
          type = "prompt";
          alignment = "left";
          newline = true;
          segments = [
            {
              type = "text";
              style = "plain";
              foreground = "#aa0011";
              foreground_templates = [ "{{ if .Root }}#ff0033{{ end }}" ];
              template = "{{ if .Root }}#   {{ else }}❯   {{ end }}";
            }
          ];
        }
      ];
    };
  };
}
