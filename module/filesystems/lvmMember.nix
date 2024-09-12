{ lib, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo str;
in
{
  options = {
    group = mkOption {
      description = "Name of the Volume Group this partition belongs to";
      type = str;
    };

    _create = mkOption {
      type = functionTo str;
      readOnly = true;
      default = device: ''
        lvm_${config.group}+=("${device}")
      '';
    };

    _mounts = mkOption {
      type = functionTo anything;
      readOnly = true;
      default = _: { };
    };
  };
}
