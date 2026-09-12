# Directory, DNS and virtual host brute-forcing
_: {
  package = p: p.gobuster;
  name = "Gobuster";
  genericName = "Directory Brute Forcer";
  comment = "Directory, DNS and virtual host brute-forcing";
  exec = "gobuster";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M4.4 2.2 15.6 1.7c.6 6.8.6 13.6.1 20.4l-11.1.4C4 15.7 4 8.9 4.4 2.2z"/>
      <circle cx="12.6" cy="12.2" r="1.6" fill="@c@" stroke="none"/>
      <path d="M18.4 8.2q.3 3.8.1 7.6M22 8q.3 4 .1 8"/>
      <path d="M6.8 22.4v1.5"/>
    '';
  };
}
