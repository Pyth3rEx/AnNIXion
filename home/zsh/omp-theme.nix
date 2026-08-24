# Prompt theme, shared by Home Manager (oh-my-posh.nix) and the system
# prompt (modules/prompt.nix). Layout and colours live in docs/zsh.md.
# The space inside each trailing diamond is the gap between segments.
# min_width drops segments as the terminal narrows.
{
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
          leading_diamond = "<#ff0033,transparent></>";
          trailing_diamond = "<#ff0033,transparent></> ";
          foreground = "#ffffff";
          background = "#252525";
          foreground_templates = [ "{{ if .Root }}#000000{{ end }}" ];
          background_templates = [ "{{ if .Root }}#ff0033{{ end }}" ];
          template = "   {{ if .Root }}☠  ROOT{{ else }}{{ .UserName }}{{ end }} @ {{ .HostName }}   ";
          properties.display_host = true;
        }
        # Path
        {
          type = "path";
          style = "diamond";
          min_width = 70;
          leading_diamond = "<#ff0033,transparent></>";
          trailing_diamond = "<#ff0033,transparent></> ";
          foreground = "#d4d4d4";
          background = "#181818";
          template = "   {{ .Path }}   ";
          properties = {
            style = "agnoster_short";
            max_depth = 4;
            home_icon = "~";
            folder_separator_icon = "<#ff0033>/</>";
          };
        }
        # Git — branch · staged(●) · working(+) · ahead(↑) · behind(↓) ·
        # stash(⚑). Muted red when clean, neon red on any change.
        {
          type = "git";
          style = "diamond";
          min_width = 105;
          leading_diamond = "<#ff0033,transparent></>";
          trailing_diamond = "<#ff0033,transparent></> ";
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
        # Nix shell — only inside nix-shell, nix develop or nix run.
        {
          type = "nix-shell";
          style = "diamond";
          min_width = 125;
          leading_diamond = "<#ff0033,transparent></>";
          trailing_diamond = "<#ff0033,transparent></> ";
          foreground = "#ff1a1a";
          background = "#131313";
          template = ''{{ if ne .Type "unknown" }}   ❄ {{ .Type }}   {{ end }}'';
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
          min_width = 135;
          leading_diamond = "";
          trailing_diamond = "<#ff0033,transparent></> ";
          foreground = "#cc1122";
          background = "#2d2d2d";
          template = ''{{ .CurrentDate | date "15:04:05" }}   '';
        }
        # Exit code — only when non-zero
        {
          type = "exit";
          style = "diamond";
          min_width = 120;
          leading_diamond = "<#ff0033,transparent></>";
          trailing_diamond = "<#ff0033,transparent></> ";
          foreground = "#ff0033";
          background = "#1e1e1e";
          template = "   ✗ {{ .Code }}   ";
          properties.always_enabled = false;
        }
        # Execution time — only when last command ran > 3 s
        {
          type = "executiontime";
          style = "diamond";
          min_width = 150;
          leading_diamond = "<#ff0033,transparent></>";
          trailing_diamond = "<#ff0033,transparent></> ";
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
          min_width = 165;
          leading_diamond = "<#ff0033,transparent></>";
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
          foreground = "#ff0033";
          template = "{{ if .Root }}#>{{ else }}$>{{ end }}";
        }
      ];
    }
  ];
}
