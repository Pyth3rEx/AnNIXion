# tlog's binaries refuse to start without their own config file in /etc/tlog
# — even an empty one is a valid configuration. This is the whole of the
# system wiring: there is nothing else to declare, because tlog-engagement
# (catalog/support/tlog.nix) takes the engagement name and --log-input as
# arguments instead of NixOS options, so changing either never needs a
# rebuild. See docs/tlog.md.
_: {
  environment.etc."tlog/tlog-rec.conf".text = "{}";
  environment.etc."tlog/tlog-play.conf".text = "{}";
}
