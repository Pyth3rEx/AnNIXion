# TCP/IP networking — listeners, pivots, file transfers
_: {
  package = p: p.netcat-gnu;
  name = "Netcat";
  genericName = "Network Swiss Army Knife";
  comment = "TCP/IP networking — listeners, pivots, file transfers";
  description = ''
    Netcat reads and writes raw TCP/UDP: a quick listener to catch a shell
    or a file, a plain client to talk to a service by hand, or a pivot
    between two ends of a connection.
  '';
  docs = "https://netcat.sourceforge.net/";
  snippets = [
    {
      label = "Listen for a connection";
      command = "nc -lvnp <port>";
    }
    {
      label = "Connect to a listener";
      command = "nc <IP> <port>";
    }
    {
      label = "Receive a file";
      command = "nc -lvnp <port> > received_file";
    }
  ];
  exec = "nc";
  launch = "term"; # konsole, closes with the tool
  # Earns a place under a second phase as well.
  alsoIn = [ "sniffing" ];
  mark = {
    class = "offensive";
    body = ''
      <path d="M1.4 7.4 8.6 6.9c.4 3.4.4 6.8.1 10.2l-7.1.4c-.4-3.3-.5-6.7-.2-10.1z"/>
      <path d="M15.4 7.4 22.6 6.9c.4 3.4.4 6.8.1 10.2l-7.1.4c-.4-3.3-.5-6.7-.2-10.1z"/>
      <path d="M8.8 11.9q3.2-.2 6.4.1"/>
      <path d="M11 9.6 8.6 12l2.3 2.4M13 9.5l2.4 2.4-2.3 2.4"/>
    '';
  };
}
