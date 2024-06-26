joinOpts: pool: { lib, name, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything attrsOf nullOr path str;
in
{
  options = {
    name = mkOption {
      description = "Name of the dataset";
      type = str;
      default = "${pool.name}/${name}";
    };

    mountpoint = mkOption {
      description = "Mount point of the dataset";
      type = nullOr path;
      default =
        let x = builtins.match "[^/]+(/.*)" name;
        in if isNull x then null else builtins.head x;
    };

    options = mkOption {
      description = "Options of the dataset";
      type = attrsOf str;
      default = { };
    };

    _create = mkOption {
      type = str;
      default = ''
        zfs create -p \
          ${joinOpts "o" config.options} \
          ${config.name}
      '';
    };

    _mounts = mkOption {
      type = anything;
      default.fileSystems.${config.mountpoint} = {
        device = config.name;
        fsType = "zfs";
        options = [ "zfsutil" ];
      };
    };
  };
}
