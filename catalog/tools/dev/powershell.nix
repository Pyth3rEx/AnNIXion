# The shell the Windows half of an engagement is written in.
_: {
  package = p: p.powershell;
  name = "PowerShell";
  genericName = "Shell";
  comment = "Cross-platform PowerShell 7";
  description = ''
    PowerShell is the shell Windows administration and tooling is written
    in — object pipelines instead of text, and cmdlets for AD, remoting and
    the rest of the Windows ecosystem.
  '';
  docs = "https://learn.microsoft.com/powershell/scripting/overview";
  snippets = [
    {
      label = "List running processes";
      command = "Get-Process";
    }
    {
      label = "Query AD for a user (RSAT)";
      command = "Get-ADUser -Identity <user> -Properties *";
    }
    {
      label = "Start a remote session";
      command = "Enter-PSSession -ComputerName <host>";
    }
  ];
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
