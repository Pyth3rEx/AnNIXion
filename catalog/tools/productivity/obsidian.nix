# Powerful knowledge base on top of a local folder of plain text Markdown files
_: {
  package = null; # ships with the desktop, not this module
  name = "Obsidian";
  genericName = "Note-Taking & Knowledge Base";
  comment = "Powerful knowledge base on top of a local folder of plain text Markdown files";
  exec = "obsidian";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "obsidian" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M12 1.6 20.4 7.4q-1.2 8.4-8.4 15Q4.8 15.8 3.6 7.4z"/>
      <path d="M8.4 9.6q3.6-.4 7.2 0M8.5 13.2q2.4-.3 4.8 0"/>
    '';
  };
}
