{ lib, my-utils, ... }:
let
  inherit (lib)
    elemAt
    mkOption
    toInt
    types;
  inherit (types)
    attrsOf
    listOf
    nullOr
    str
    submodule;

  inherit (my-utils) adt;

  path = str;

  listIx = name:
    # name is of the form: [definition X-entry Y]
    let res = builtins.match "[[]definition ([0-9]+)-entry ([0-9]+)[]]" name; in
    assert res != null; {
      def = toInt (elemAt res 0);
      ent = toInt (elemAt res 1);
    };

  # submodule definitions

  disk = { name, config, ... }: {
    options = {
      device = mkOption {
        type = path;
        description = "Path to the disk device file";
        default = name;
      };
      type = mkOption {
        type = str;
        description = "Partition table type";
        default = "gpt";
      };
      partSep = mkOption {
        type = str;
        description = ''
          Separator text between disk path and partition number.
          Examples:
          - /dev/sda1 -> empty string
          - /dev/nvme0n1p1 -> "p"
          - /dev/disk/by-id/foo-part1 -> "-part"
        '';
        default = "-part";
      };
      partitions = mkOption {
        type = listOf (submodule (partition config));
        description = ''
          List of partitions.
          Can only be defined once per disk in your whole config!
          Multiple definitions would lose a guaranteed partition ordering.
        '';
      };
    };
  };

  partition = disk: { name, ... }: {
    options = {
      device = mkOption {
        type = str;
        description = "Path to the partition device file";
        default = let ix = listIx name; in
          assert ix.def == 1; # there can only be one partition list per disk
          "${disk.device}${disk.partSep}${toString ix.ent}";
      };
      type = mkOption {
        type = str;
        description = "Partition type (read by sfdisk)";
      };
      size = mkOption {
        type = nullOr str;
        description = ''
          Size of the partition.
          null means remaining size.
        '';
      };
      content = mkOption {
        type = adt.mkOneOf partitionContent;
      };
    };
  };

  partitionContent = {
    inherit filesystem zpool;
    # zpool = zpoolRef;
  };

  filesystem.options = {
    type = mkOption {
      type = str;
      description = "Filesystem type (read by mkfs)";
    };
    mkfsOpts = mkOption {
      type = listOf str;
      description = "Options for mkfs";
      default = [ ];
    };

    mountpoint = mkOption {
      type = path;
      description = "Mount point of the filesystem";
    };
    mountOpts = mkOption {
      type = listOf str;
      description = "Options for mount";
      default = [ "defaults" ];
    };
  };

  # ok this is funny:
  # name is the actual pool name in aquaris.filesystem.zpools
  # which of course makes no sense with adt.addTag
  # but when creating the submodule, name is "zpool"
  # which is exactly the tag name we need
  zpool = { name, ... }: adt.addTag name {
    options = {
      name = mkOption {
        type = str;
        description = "Name of the zpool";
        default = name;
      };

      poolOpts = mkOption {
        type = attrsOf str;
        description = "Options set on pool creation";
        default = {
          ashift = "12";
          autoexpand = "on";
          autoreplace = "on";
          autotrim = "on";
          listsnapshots = "on";
        };
      };
      rootOpts = mkOption {
        type = attrsOf str;
        description = "Default options for all datasets";
        default = {
          acltype = "posix";
          compression = "zstd";
          dnodesize = "auto";
          mountpoint = "none";
          normalization = "formD";
          relatime = "on";
          xattr = "sa";
        };
      };

      datasets = mkOption {
        type = types.anything;
      };
    };
  };
in
{
  options.aquaris.filesystem = mkOption {
    type = types.submoduleWith {
      specialArgs = {
        inherit (adt.mkTagger partitionContent) filesystem zpool;
      };

      modules = [{
        options = {
          disks = mkOption {
            type = attrsOf (submodule disk);
            default = { };
          };

          zpools = mkOption {
            type = attrsOf (submodule zpool);
            default = { };
          };
        };
      }];
    };
  };
}
