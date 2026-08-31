# Branded artwork for the surfaces outside the desktop session: the boot
# splash, the login screen and the installer image. Rules: docs/visual-identity.md.
{ pkgs }:

let
  mark = ../assets/icons/AnNIXion.png;
  banner = ../banner.png;
  wallpaper = ../assets/wallpaper/wallpaper_2.png;

  # The banner ships on #0D0D0D, so dropping it straight onto black leaves a
  # visible panel. Key that shade out first, then flatten onto true black.
  onBlack =
    name: width: geometry:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick ${banner} -fuzz 14% -transparent '#0D0D0D' \
        -resize ${toString width}x -background black -gravity center \
        -extent ${geometry} -flatten $out
    '';
in
rec {
  # ── Boot splash ───────────────────────────────────────────────────────────
  plymouthTheme =
    pkgs.runCommand "annixion-plymouth-theme"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        d=$out/share/plymouth/themes/annixion
        mkdir -p "$d"

        magick ${mark} -resize 512x512 "$d/logo.png"
        magick -size 8x8 xc:'#FF0033' "$d/bar.png"
        magick -size 8x8 xc:'#2A2F3A' "$d/bar-bg.png"

        cat > "$d/annixion.plymouth" <<'EOF'
        [Plymouth Theme]
        Name=AnNIXion
        Description=AnNIXion boot splash
        ModuleName=script

        [script]
        ImageDir=/etc/plymouth/themes/annixion
        ScriptFile=/etc/plymouth/themes/annixion/annixion.script
        EOF

        cp ${plymouthScript} "$d/annixion.script"
      '';

  plymouthScript = pkgs.writeText "annixion.script" ''
    # AnNIXion boot splash. The mark on the void ground, one red progress rule.
    Window.SetBackgroundTopColor(0.055, 0.059, 0.075);
    Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

    screen_width = Window.GetWidth();
    screen_height = Window.GetHeight();

    logo_size = screen_height * 0.26;
    logo_image = Image("logo.png").Scale(logo_size, logo_size);
    logo_x = screen_width / 2 - logo_size / 2;
    logo_y = screen_height / 2 - logo_size / 2 - screen_height * 0.06;
    logo_sprite = Sprite(logo_image);
    logo_sprite.SetPosition(logo_x, logo_y, 0);

    bar_width = screen_width * 0.20;
    bar_height = 3;
    bar_x = screen_width / 2 - bar_width / 2;
    bar_y = logo_y + logo_size + screen_height * 0.07;

    bar_track = Sprite(Image("bar-bg.png").Scale(bar_width, bar_height));
    bar_track.SetPosition(bar_x, bar_y, 1);

    bar_source = Image("bar.png");
    bar_fill = Sprite();
    bar_fill.SetPosition(bar_x, bar_y, 2);

    fun on_progress (duration, progress) {
      filled = bar_width * progress;
      if (filled < 1) {
        filled = 1;
      }
      bar_fill.SetImage(bar_source.Scale(filled, bar_height));
    }
    Plymouth.SetBootProgressFunction(on_progress);

    # ── Password prompt, for an encrypted root ──────────────────────────────
    prompt_sprite = Sprite();
    prompt_sprite.SetPosition(0, 0, 5);

    fun on_password (prompt, bullets) {
      stars = "";
      i = 0;
      while (i < bullets) {
        stars = stars + "*";
        i = i + 1;
      }
      text = Image.Text(prompt + "  " + stars, 0.87, 0.89, 0.92);
      prompt_sprite.SetImage(text);
      prompt_sprite.SetPosition(
        screen_width / 2 - text.GetWidth() / 2,
        bar_y + screen_height * 0.06,
        5);
    }
    Plymouth.SetDisplayPasswordFunction(on_password);

    fun on_normal () {
      prompt_sprite.SetImage(Image.Text("", 0, 0, 0));
    }
    Plymouth.SetDisplayNormalFunction(on_normal);

    fun on_message (text) {
      message = Image.Text(text, 0.51, 0.55, 0.62);
      prompt_sprite.SetImage(message);
      prompt_sprite.SetPosition(
        screen_width / 2 - message.GetWidth() / 2,
        bar_y + screen_height * 0.06,
        5);
    }
    Plymouth.SetMessageFunction(on_message);
  '';

  # ── Login screen ──────────────────────────────────────────────────────────
  # Breeze's greeter is entirely driven by theme.conf, so rebranding it needs
  # no QML of our own — which is the whole point. A greeter that fails to load
  # leaves no way into the machine.
  sddmTheme =
    pkgs.runCommand "annixion-sddm-theme"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        src=${pkgs.kdePackages.plasma-desktop}/share/sddm/themes/breeze
        d=$out/share/sddm/themes/annixion
        mkdir -p "$d"
        cp -r "$src"/. "$d"
        chmod -R u+w "$d"

        magick ${mark} -resize 320x320 "$d/annixion-logo.png"
        cp ${wallpaper} "$d/background.png"

        cat > "$d/theme.conf" <<EOF
        [General]
        type=image
        background=$d/background.png
        logo=$d/annixion-logo.png
        showlogo=visible
        showClock=true
        color=#FF0033
        fontSize=10
        needsFullUserModel=false
        EOF

        # Drop Breeze's translated names, or every non-English locale still
        # reads "Breeze" at the greeter.
        sed -i -e '/^Name\[/d' -e '/^Description\[/d' \
          -e 's/^Name=.*/Name=AnNIXion/' \
          -e 's/^Description=.*/Description=AnNIXion login/' \
          -e 's/^Theme-Id=.*/Theme-Id=annixion/' \
          "$d/metadata.desktop"
      '';

  # ── Installer image ───────────────────────────────────────────────────────
  # syslinux draws the BIOS menu over a 640x480 image; GRUB takes the EFI one.
  isoSplashBios = onBlack "annixion-iso-splash-bios.png" 560 "640x480";
  isoSplashEfi = onBlack "annixion-iso-splash-efi.png" 1280 "1920x1080";
}
