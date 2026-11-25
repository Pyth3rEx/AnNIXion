# Firmware analysis and extraction
{ bodies }:
{
  package = p: p.binwalk;
  name = "Binwalk";
  genericName = "Firmware Analyzer";
  comment = "Firmware analysis and extraction";
  description = ''
    Binwalk scans a firmware image for embedded files and executable code
    by signature — file systems, compressed archives, bootloaders — and
    extracts whatever it finds.
  '';
  docs = "https://github.com/ReFirmLabs/binwalk/wiki";
  snippets = [
    {
      label = "Scan for embedded signatures";
      command = "binwalk firmware.bin";
    }
    {
      label = "Extract everything found";
      command = "binwalk -e firmware.bin";
    }
    {
      label = "Extract recursively, scan unknown blobs by entropy";
      command = "binwalk -Me firmware.bin";
    }
  ];
  exec = "binwalk";
  launch = "hold"; # konsole, shell kept open afterwards
  # Earns a place under a second phase as well.
  alsoIn = [ "re/firmware" ];
  mark = {
    class = "reverse";
    body = bodies.binwalk;
    over = bodies.binwalkOver;
  };
}
