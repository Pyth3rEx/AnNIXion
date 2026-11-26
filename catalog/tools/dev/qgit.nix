# Git GUI — provider-agnostic, unlike GitHub Desktop
_: {
  package = p: p.qgit;
  name = "QGit";
  genericName = "Git GUI";
  comment = "Graphical history, diff and commit browser for any git repository";
  description = "QGit browses a repository's history as a graph, with side-by-side diffs and a commit/file browser — provider-agnostic, unlike GitHub Desktop.";
  docs = "https://github.com/tibirna/qgit";
  exec = "qgit";
  launch = "gui"; # runs directly
  mark = {
    class = "utility";
    body = ''
      <circle cx="6" cy="4.6" r="2.6" fill="@c@" stroke="none"/>
      <circle cx="6" cy="19.4" r="2.6" fill="@c@" stroke="none"/>
      <circle cx="18.2" cy="9.4" r="2.6" fill="@c@" stroke="none"/>
      <path d="M6 7.2q-.2 4.8 0 9.6"/>
      <path d="M18.2 12q.2 4-3.4 6.2-3.4 2-8.5 1.3"/>
    '';
  };
}
