# home/panel-separator.nix — com.annixion.separator, a hairline rule for the panel.
# Plasma 5 shipped org.kde.plasma.marginsseparator; Plasma 6 dropped it and
# offers nothing in its place, so the rule is ours. Installed as a plain
# KPackage under ~/.local/share, which is where Plasma looks after its own
# prefixes — no activation hook needed.
_:

let
  id = "com.annixion.separator";
  pkgRoot = ".local/share/plasma/plasmoids/${id}";
in
{
  home.file = {
    "${pkgRoot}/metadata.json".text = builtins.toJSON {
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
    };

    # Kirigami.Theme.textColor rather than the signature red: the rule divides
    # the bar, it does not decorate it, and it has to stay readable if the panel
    # is ever put on a light theme.
    "${pkgRoot}/contents/ui/main.qml".text = ''
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
  };
}
