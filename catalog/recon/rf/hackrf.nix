# HackRF hardware interface and diagnostics
_: {
  package = p: p.hackrf;
  name = "HackRF Tools";
  genericName = "HackRF Utilities";
  comment = "HackRF hardware interface and diagnostics";
  description = ''
    The HackRF command-line tools talk to the HackRF One SDR directly:
    confirm the device is seen, sweep a frequency range for signal power,
    or capture/transmit raw IQ samples.
  '';
  docs = "https://hackrf.readthedocs.io/";
  snippets = [
    {
      label = "Confirm the device is seen";
      command = "hackrf_info";
    }
    {
      label = "Sweep a frequency range for signal power";
      command = "hackrf_sweep -f 2400:2500";
    }
    {
      label = "Capture raw IQ samples";
      command = "hackrf_transfer -r capture.iq -f 915000000 -s 2000000";
    }
  ];
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
