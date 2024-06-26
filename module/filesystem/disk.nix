util: { lib, name, config, ... }:
let
  inherit (lib) mkOption pipe;
  inherit (lib.types) anything listOf path str submodule;

  partition = import ./partition.nix util.fs;
in
{
  options = {
    device = mkOption {
      description = "Path to the disk device file";
      type = path;
      default = name;
    };

    type = mkOption {
      description = "Partition table type";
      type = str;
      default = "gpt";
    };

    separator = mkOption {
      description = "Separator between disk path and partition number";
      type = str;
      default = "-part";
    };

    partitions = mkOption {
      description = "Partitions on this disk";
      type = listOf (submodule (partition config));
    };

    _create = mkOption {
      type = str;
      default = ''
        wipefs -af "${config.device}"
        sfdisk "${config.device}" << EOF
        label: ${config.type}
        ${util.getEntries (x: x._entry) config.partitions}
        EOF
        udevadm settle
        ${util.getEntries (x: x._create) config.partitions}
      '';
    };

    _mounts = mkOption {
      type = anything;
      default = pipe config.partitions [
        (map (x: x._mounts))
        util.merge
      ];
    };
  };
}
