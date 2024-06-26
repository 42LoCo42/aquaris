fs: disk: { lib, name, config, ... }:
let
  inherit (lib) elemAt mkOption toInt;
  inherit (lib.types) anything nullOr path str;

  listIx = name:
    # name is of the form: [definition X-entry Y]
    let res = builtins.match "[[]definition ([0-9]+)-entry ([0-9]+)[]]" name; in
    assert res != null; {
      def = toInt (elemAt res 0);
      ent = toInt (elemAt res 1);
    };
in
{
  options = {
    device = mkOption {
      description = "Path to the partition device file";
      type = path;
      default = let ix = listIx name; in
        assert ix.def == 1; # there can only be one partition list per disk
        "${disk.device}${disk.separator}${toString ix.ent}";
    };

    type = mkOption {
      description = "Partition type for sfdisk";
      type = str;
      default = if fs.is.swap config.content then "swap" else "linux";
    };

    size = mkOption {
      description = "Size of the partition for sfdisk (null = remaining size)";
      type = nullOr str;
      default = null;
    };

    content = mkOption {
      description = "Partition content";
      type = fs.type;
    };

    _entry = mkOption {
      type = str;
      default = builtins.concatStringsSep "," (
        [ "type=${config.type}" ] ++
        (if config.size != null then [ "size=${config.size}" ] else [ ])
      );
    };

    _create = mkOption {
      type = str;
      default = ''
        wipefs -af "${config.device}"
        ${config.content._create config.device}
      '';
    };

    _mounts = mkOption {
      type = anything;
      default = config.content._mounts config.device;
    };
  };
}
