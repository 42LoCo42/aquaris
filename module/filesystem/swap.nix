{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo str;
in
{
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
