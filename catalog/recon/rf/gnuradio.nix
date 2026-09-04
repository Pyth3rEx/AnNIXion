# SDR flow-graph signal processing toolkit
_: {
  package = p: p.gnuradio;
  name = "GNU Radio Companion";
  genericName = "SDR Signal Processing";
  comment = "SDR flow-graph signal processing toolkit";
  exec = "gnuradio-companion";
  launch = "gui"; # runs directly
  mark = {
    class = "probe";
    body = ''
      <path d="M1.4 6.2 8.6 5.7c.4 2.6.4 5.2.1 7.8l-7.1.4c-.4-2.5-.5-5.1-.2-7.7z"/>
      <path d="M15.4 10.6 22.6 10.1c.4 2.6.4 5.2.1 7.8l-7.1.4c-.4-2.5-.5-5.1-.2-7.7z"/>
      <path d="M8.8 9.6q3.2-.2 6.4 4.6"/>
      <path d="M13.4 12.4 15.4 14.2 13.2 15.9"/>
      <path d="M4.2 13.8v3.4"/>
    '';
  };
}
