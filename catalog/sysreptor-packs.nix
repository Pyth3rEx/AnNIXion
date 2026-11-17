# Helpers for building SysReptor design/project/template packs — split out
# of sysreptor.nix so a user can build HTB/OffSec packs the same way this
# repo builds its own, without this repo ever fetching them.
{ pkgs }:
{
  # Official designs/templates, as `manage.py importdemodata` takes them.
  # Upstream publishes these at unversioned URLs and regenerates them on
  # every docs deploy, minting fresh asset UUIDs each time — so a hash over
  # the archive is not a pin, it is a time bomb that goes off within days on
  # a change that is not a change.
  #
  # The fetch therefore yields canonicalised content rather than the
  # archive: asset ids derived from the name the importer actually matches
  # on, JSON sorted, no timestamps. The hash then moves only when upstream
  # changes something real, such as adding a design.
  # scripts/sysreptor-canonicalise.py explains the rest, and prints a new
  # hash when one is needed.
  #
  # Not used by the default package — see sysreptor.nix, which only ever
  # builds the in-repo design-annixion/template-annixion packs. A user who
  # wants HTB/OffSec content calls this directly from their own
  # user/configuration.nix and fetches/pins it there; see docs/sysreptor.md.
  designPack =
    name: hash:
    pkgs.fetchurl {
      url = "https://docs.sysreptor.com/assets/${name}.tar.gz";
      sha256 = hash;
      recursiveHash = true;
      downloadToTemp = true;
      nativeBuildInputs = [ pkgs.python3 ];
      postFetch = ''
        mkdir -p $out
        tar xzf $downloadedFile -C $out
        python3 ${../../../scripts/sysreptor-canonicalise.py} $out
      '';
    };

  # Repacked from the canonicalised tree, in a fixed order and with no
  # timestamps, so the archive handed to the importer is byte-identical per
  # rebuild. The `./` prefix tar writes for `-C dir .` is transformed away:
  # the importer looks an asset up as the exact member name
  # `<id>-assets/<name>`, and `./<id>-assets/<name>` is not that name, so a
  # design with assets fails to import.
  #
  # Returns a derivation (not a shell snippet), named `<kind>` with its
  # tar.gz at `$out/<kind>.tar.gz` — so a list of these `symlinkJoin`s into a
  # flat directory of `<kind>.tar.gz` files, exactly the shape
  # annixion.sysreptor.extraDesigns and the wrapper's `pack_path` expect.
  packCmd =
    kind: src:
    pkgs.runCommand kind { } ''
      mkdir -p $out
      tar -czf $out/${kind}.tar.gz \
        --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner \
        --transform='s|^\./||' \
        -C ${src} .
      chmod 444 $out/${kind}.tar.gz
    '';
}
