# GUI frontend for The Sleuth Kit disk forensics
_: {
  package = p: p.autopsy;
  name = "Autopsy";
  genericName = "Digital Forensics Platform";
  comment = "GUI frontend for The Sleuth Kit disk forensics";
  exec = "autopsy";
  launch = "gui"; # runs directly
  mark = {
    class = "forensic";
    body = ''
      <path d="M21.1 14.1c-1.3 4-5.1 6.9-9.3 6.8C6.5 20.8 2.2 16.3 2.3 11 2.4 5.8 6.8 1.7 12.1 1.8c4.9.1 9 3.8 9.5 8.6"/>
      <circle cx="12" cy="12" r="1.9" fill="@c@" stroke="none"/>
      <path d="M12 12 19.4 6.4"/>
      <path d="M11.8 21v2.6"/>
    '';
  };
}
