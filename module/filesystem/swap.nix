addTag: { name, lib, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo str;
in
addTag name {
  options = {
    _create = mkOption {
      type = functionTo str;
      default = device: ''
        mkswap --verbose ${device}
      '';
    };

    _mounts = mkOption {
      type = functionTo anything;
      default = device: {
        swapDevices = [{ inherit device; }];
      };
    };
  };
}
