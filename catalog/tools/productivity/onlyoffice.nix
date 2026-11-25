# Office productivity suite — documents, spreadsheets, presentations
{ bodies }:
{
  package = null; # ships with the desktop, not this module
  name = "OnlyOffice";
  genericName = "Office Suite";
  comment = "Office productivity suite — documents, spreadsheets, presentations";
  description = "OnlyOffice Desktop Editors handle documents, spreadsheets and presentations with strong Microsoft Office format compatibility, for report writing and client deliverables.";
  docs = "https://helpcenter.onlyoffice.com/";
  exec = "onlyoffice-desktopeditors";
  launch = "gui"; # runs directly
  # Ships its own .desktop, which asks for the stock icon name;
  # the mark is installed under that name too or the launcher
  # falls through to an inherited theme.
  aliases = [ "onlyoffice-desktopeditors" ];
  mark = {
    class = "utility";
    body = bodies.onlyoffice;
  };
}
