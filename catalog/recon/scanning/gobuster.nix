# Directory, DNS and virtual host brute-forcing
_: {
  package = p: p.gobuster;
  name = "Gobuster";
  genericName = "Directory Brute Forcer";
  comment = "Directory, DNS and virtual host brute-forcing";
  description = ''
    Gobuster brute-forces three different things depending on the mode:
    directories/files on a web server, DNS subdomains, or virtual hosts —
    each by trying every entry in a wordlist.
  '';
  docs = "https://github.com/OJ/gobuster#readme";
  snippets = [
    {
      label = "Directory brute-force";
      command = "gobuster dir -u http://<target> -w /run/current-system/sw/share/wordlists/seclists/Discovery/Web-Content/common.txt";
    }
    {
      label = "DNS subdomain brute-force";
      command = "gobuster dns -d <domain> -w wordlist.txt";
    }
    {
      label = "Virtual host brute-force";
      command = "gobuster vhost -u http://<target> -w wordlist.txt";
    }
  ];
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
