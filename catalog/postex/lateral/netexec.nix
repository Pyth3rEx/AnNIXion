# Credential validation and remote execution across SMB/WinRM/MSSQL/LDAP —
# maintained fork of the retired CrackMapExec.
_: {
  package = p: p.netexec;
  name = "NetExec";
  genericName = "Network Service Exploitation";
  comment = "Credential validation, command execution and lateral movement across AD hosts";
  exec = "netexec";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "offensive";
    body = ''
      <path d="M2.3 4.7 6.9 4.2q.4 2.7 0 5.4l-4.4.3q-.4-2.9-.1-5.9z"/>
      <path d="M9.5 9.9 14.1 9.4q.4 2.8 0 5.6l-4.4.4q-.4-3-.2-6z"/>
      <path d="M16.3 15.5 20.9 15q.4 2.7 0 5.4l-4.4.4q-.4-2.9-.1-5.9z"/>
    '';
    over = ''
      <path d="M21.2 2.5 2.6 21.6"/>
    '';
  };
}
