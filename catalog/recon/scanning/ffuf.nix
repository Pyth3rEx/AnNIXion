# Fast web fuzzer
_: {
  package = p: p.ffuf;
  name = "ffuf";
  genericName = "Web Fuzzer";
  comment = "Fast web fuzzer";
  exec = "ffuf";
  launch = "hold"; # konsole, shell kept open afterwards
  mark = {
    class = "probe";
    body = ''
      <path d="M1.6 5.4q3.4-.4 6.8 0M1.7 12q3.3-.3 6.6.1M1.6 18.6q3.4-.4 6.8 0"/>
      <path d="M9.4 5.6 15.6 11.8 9.6 18.4"/>
      <path d="M14.4 11.9q3.9-.3 7.8 0"/>
      <path d="M19.4 8.6 22.8 11.9 19.5 15.4"/>
    '';
  };
}
