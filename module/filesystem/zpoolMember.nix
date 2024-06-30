{ lib, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo str;
in
{
  options = {
    pool = mkOption {
      description = "Name of the zpool this partition belongs to";
      type = str;
    };

    _create = mkOption {
      type = functionTo str;
      default = device: ''
        zpool_${config.pool}+=("${device}")
      '';
    };

    _mounts = mkOption {
      type = functionTo anything;
      default = _: { };
    };
  };
}
