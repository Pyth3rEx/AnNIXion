# Markdown Viewer
_: {
  package = p: p.glow;
  name = "Glow";
  genericName = "Markdown Viewer";
  comment = "Render Markdown on the command line";
  exec = "glow %f";
  launch = "term"; # konsole, closes with the tool
  mimeType = [ "text/markdown" ];
  mark = {
    class = "utility";
    body = ''
      <path d="M2.3 5.1 21.8 4.6q.5 8.6-.1 17.2l-19.3.5C2 19.8 1.9 12.4 2.3 5.1z"/>
      <path d="M9.1 6.6q-.4 5.1-.9 10.1M13.6 6.4q-.2 5.3-.5 10.6"/>
      <path d="M6.8 9.8q3.9-.4 7.8 0M6.6 13.7q4.1-.3 8.2 .1"/>
      <path d="M6.5 17.6q5.4-.4 10.8 0"/>
    '';
  };
}
