# The shell the Windows half of an engagement is written in.
_: {
  package = p: p.powershell;
  name = "PowerShell";
  genericName = "Shell";
  comment = "Cross-platform PowerShell 7";
  exec = "pwsh";
  launch = "term"; # konsole, closes with the tool
  # The prompt chevron, unframed: bodies.terminal is the same two strokes
  # inside a window, worn by all three konsoles.
  mark = {
    class = "utility";
    body = ''
      <path d="M4.6 3.9Q9.4 8.6 15.4 11.7 10.4 16.6 4.2 19.8"/>
      <path d="M11.8 19.8Q16.4 20.5 21.3 19.2"/>
    '';
  };
}
