# Fast web fuzzer
_: {
  package = p: p.ffuf;
  name = "ffuf";
  genericName = "Web Fuzzer";
  comment = "Fast web fuzzer";
  description = ''
    ffuf fuzzes anything in an HTTP request — paths, parameters, headers,
    virtual hosts — by substituting a `FUZZ` placeholder from a wordlist and
    filtering responses by size, status or word count.
  '';
  docs = "https://github.com/ffuf/ffuf/wiki";
  snippets = [
    {
      label = "Directory/path fuzzing";
      command = "ffuf -u http://<target>/FUZZ -w /run/current-system/sw/share/wordlists/seclists/Discovery/Web-Content/big.txt";
    }
    {
      label = "Fuzz a POST parameter, filter out failed logins";
      command = ''ffuf -u http://<target>/login -X POST -d "user=admin&pass=FUZZ" -w wordlist.txt -fc 401'';
    }
  ];
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
