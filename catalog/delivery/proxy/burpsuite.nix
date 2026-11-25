# Web application security testing platform
{ bodies }:
{
  package = p: p.burpsuite;
  name = "Burp Suite";
  genericName = "Web App Security Proxy";
  comment = "Web application security testing platform";
  description = ''
    Burp Suite is an intercepting proxy for testing web applications:
    Proxy to inspect and modify traffic, Repeater to replay and tamper with
    individual requests, Intruder for automated fuzzing, and a scanner for
    automated vulnerability discovery.
  '';
  docs = "https://portswigger.net/burp/documentation";
  exec = "burpsuite";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "burpsuite" ];
  mark = {
    class = "offensive";
    body = bodies.burpsuite;
    over = bodies.burpsuiteOver;
  };
}
