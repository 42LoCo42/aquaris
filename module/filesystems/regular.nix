{ lib, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo listOf path str;
in
{
  options = {
    type = mkOption {
      description = "Filesystem type for mkfs";
      type = str;
    };

    mkfsOpts = mkOption {
      description = "Options for mkfs";
      type = listOf str;
      default = [ ];
    };

    mountpoint = mkOption {
      description = "Mount point of the filesystem";
      type = path;
    };

    mountOpts = mkOption {
      description = "Options for mount";
      type = listOf str;
      default = [ ];
    };

    _create = mkOption {
      type = functionTo str;
      readOnly = true;
      default = device: ''
        mkfs --verbose --type ${config.type} \
          ${builtins.concatStringsSep " " config.mkfsOpts} \
          ${device}
      '';
    };

    _mounts = mkOption {
      type = functionTo anything;
      readOnly = true;
      default = device: {
        fileSystems.${config.mountpoint} = {
          inherit device;
          fsType = config.type;
          options = config.mountOpts;
        };
      };
    };
  };

  config = {
    mountOpts = [ "defaults" "nosuid" ];
  };
}
