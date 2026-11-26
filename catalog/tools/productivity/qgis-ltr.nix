# Mapping and geospatial analysis — building maps for reports. LTR: this
# distribution is version-locked, so the long-term-release branch is the one
# that keeps working without chasing QGIS's own release cadence.
_: {
  package = p: p.qgis-ltr;
  name = "QGIS";
  genericName = "GIS / Mapping";
  comment = "Geospatial analysis and map authoring";
  description = "QGIS handles geospatial analysis and map authoring — layering imagery, coordinates and overlays into maps for a report, on the version-locked LTR branch.";
  docs = "https://docs.qgis.org/";
  exec = "qgis";
  launch = "gui"; # runs directly
  # Ships its own .desktop (org.qgis.qgis.desktop), which asks for the stock
  # icon name "qgis"; the mark is installed under that name too or the
  # launcher falls through to an inherited theme.
  aliases = [ "qgis" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M2.2 6.4 8 3.2l7.9 3.2 5.9-3V18l-5.9 3-7.9-3.2-5.8 3z"/>
      <path d="M8 3.2v14.8M15.9 6.4v14.8"/>
      <circle cx="12" cy="11.5" r="2.2" fill="@c@" stroke="none"/>
    '';
  };
}
