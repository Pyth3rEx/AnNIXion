# home/desktop/panel-separator.nix — com.annixion.separator, a hairline rule for the panel.
# Plasma 5 shipped org.kde.plasma.marginsseparator; Plasma 6 dropped it and
# offers nothing in its place, so the rule is ours.
#
# Built as a derivation and copied into place by an activation script, not
# shipped via home.file: home.file symlinks each package file individually,
# and those symlinks resolve outside ~/.local/share/plasma/plasmoids/<id>/ —
# which trips KPackage's path-traversal guard ("Path traversal attempt
# detected") and the applet fails to load, silently and without a
# stack the panel will admit to. home/default.nix's installTiledMenu
# activation script sidesteps the same trap for the same reason.
{
  pkgs,
  lib,
  ...
}:

let
  id = "com.annixion.separator";
  pkgRoot = ".local/share/plasma/plasmoids/${id}";

  metadata = pkgs.writeText "metadata.json" (
    builtins.toJSON {
      KPackageStructure = "Plasma/Applet";
      KPlugin = {
        Id = id;
        Name = "AnNIXion Separator";
        Description = "A hairline rule between panel groups";
        Category = "Windows and Tasks";
        Icon = "draw-line";
        License = "MIT";
        Version = "1.0";
      };
      # Without this Plasma treats the package as a Plasma 5 applet and skips it.
      "X-Plasma-API-Minimum-Version" = "6.0";
    }
  );

  # Kirigami.Theme.textColor rather than the signature red: the rule divides
  # the bar, it does not decorate it, and it has to stay readable if the panel
  # is ever put on a light theme.
  mainQml = pkgs.writeText "main.qml" ''
    import QtQuick
    import QtQuick.Layouts
    import org.kde.plasma.core as PlasmaCore
    import org.kde.plasma.plasmoid
    import org.kde.kirigami as Kirigami

    PlasmoidItem {
        // A compact representation would collapse the rule to a tray icon.
        preferredRepresentation: fullRepresentation

        // fullRepresentation is a Component, so everything it needs is
        // declared inside it: reaching back out to an id here reads as an
        // unqualified access and breaks under ComponentBehavior: Bound.
        fullRepresentation: Item {
            id: rule

            readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal

            Layout.fillWidth: !rule.horizontal
            Layout.fillHeight: rule.horizontal
            Layout.preferredWidth: rule.horizontal ? Kirigami.Units.smallSpacing * 3 : -1
            Layout.preferredHeight: rule.horizontal ? -1 : Kirigami.Units.smallSpacing * 3

            Rectangle {
                anchors.centerIn: parent
                width: rule.horizontal ? 1 : Math.round(rule.width * 0.6)
                height: rule.horizontal ? Math.round(rule.height * 0.5) : 1
                color: Kirigami.Theme.textColor
                opacity: 0.4
            }
        }
    }
  '';

  package = pkgs.runCommand "plasma-applet-annixion-separator" { } ''
    dest=$out/share/plasma/plasmoids/${id}
    mkdir -p "$dest/contents/ui"
    cp ${metadata} "$dest/metadata.json"
    cp ${mainQml} "$dest/contents/ui/main.qml"
  '';
in
{
  # Plasma only scans ~/.local/share/plasma/plasmoids/ at session start, and
  # KPackage rejects a symlinked package (see above), so this has to be a real
  # copy laid down before that scan, same as installTiledMenu.
  home.activation.installPanelSeparator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _sep="$HOME/${pkgRoot}"
    [ -d "$_sep" ] && $DRY_RUN_CMD chmod -R u+w "$_sep"
    $DRY_RUN_CMD rm -rf "$_sep"
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share/plasma/plasmoids"
    $DRY_RUN_CMD cp -rL "${package}/share/plasma/plasmoids/${id}" "$_sep"
    $DRY_RUN_CMD chmod -R u+w "$_sep"
  '';
}
