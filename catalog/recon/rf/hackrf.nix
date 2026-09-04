# HackRF hardware interface and diagnostics
_: {
  package = p: p.hackrf;
  name = "HackRF Tools";
  genericName = "HackRF Utilities";
  comment = "HackRF hardware interface and diagnostics";
  exec = "hackrf_info";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M2.4 8.4 13.6 7.9c.4 2.8.4 5.6.1 8.4l-11.1.4c-.4-2.7-.5-5.5-.2-8.3z"/>
      <path d="M5.4 16.6q.2 2.2 0 4.4M10.4 16.5q.2 2.2 0 4.4"/>
      <path d="M16.4 9.4c1.8 1.6 1.9 4.2.1 5.9"/>
      <path d="M19.4 6.4c3.4 3.1 3.6 8.4.2 11.7"/>
    '';
  };
}
