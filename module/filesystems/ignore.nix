{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo str;
in
{
  options = {
    _create = mkOption {
      type = functionTo str;
      readOnly = true;
      default = _: "";
    };

    _mounts = mkOption {
      type = functionTo anything;
      readOnly = true;
      default = _: { };
    };
  };
}
