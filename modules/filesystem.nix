{ pkgs, config, lib, my-utils, ... }:
let
  inherit (lib)
    elemAt
    mapAttrsToList
    mkOption
    pipe
    toInt
    types;
  inherit (types)
    attrsOf
    lines
    listOf
    nullOr
    package
    path
    str
    submodule;

  inherit (my-utils) adt;

  cfg = config.aquaris.filesystem;

  ##### utils #####

  listIx = name:
    # name is of the form: [definition X-entry Y]
    let res = builtins.match "[[]definition ([0-9]+)-entry ([0-9]+)[]]" name; in
    assert res != null; {
      def = toInt (elemAt res 0);
      ent = toInt (elemAt res 1);
    };

  getEntries = f: v: builtins.concatStringsSep "\n" (map f v);
  getEntriesA = f: v: getEntries f (builtins.attrValues v);

  joinOpts = chr: options: pipe options [
    (mapAttrsToList (name: val: "-${chr} ${name}=${val}"))
    (builtins.concatStringsSep " ")
  ];

  zpoolDevices = zpool: pipe cfg.disks [
    (mapAttrsToList (_: val: pipe val.partitions [
      (builtins.filter (p:
        partitionContent.is.zpool p.content &&
        p.content.name == zpool.name))
      (map (p: p.device))
    ]))
    builtins.concatLists
    (builtins.concatStringsSep " ")
  ];

  slashSort = attrs: pipe attrs [
    (mapAttrsToList (name: val: {
      prio = builtins.length (builtins.split "/" name);
      inherit val;
    }))
    (builtins.sort (i1: i2: i1.prio < i2.prio))
    (map (i: i.val))
  ];

  ##### submodule definitions #####

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

      _format = mkOption {
        type = lines;
        default = ''
          wipefs -af "${config.device}"
          sfdisk "${config.device}" <<EOF
          label: ${config.type}
          ${getEntries (p: p._sfdiskEntry) config.partitions}
          EOF
          ${getEntries (p: p._mkfs) config.partitions}
        '';
      };
    };
  };

  partition = disk: { name, config, ... }: {
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
        default = "linux";
      };
      size = mkOption {
        type = nullOr str;
        description = ''
          Size of the partition.
          null means remaining size.
        '';
        default = null;
      };
      content = mkOption {
        type = partitionContentT;
      };

      _sfdiskEntry = mkOption {
        type = str;
        default = builtins.concatStringsSep ","
          ([ "type=${config.type}" ] ++
            (if config.size != null then [ "size=${config.size}" ] else [ ]));
      };

      _mkfs = mkOption {
        type = lines;
        default =
          if partitionContent.is.zpool config.content then "" else ''
            wipefs -af "${config.device}"
            mkfs --verbose --type="${config.content.type}"              \
              ${builtins.concatStringsSep " " config.content.mkfsOpts}  \
              "${config.device}"
          '';
      };
    };
  };

  partitionContentC = { inherit filesystem zpool; };
  partitionContentT = adt.mkOneOf partitionContentC;
  partitionContent = adt.mkTagger partitionContentC;

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
  zpool = { name, config, ... }: adt.addTag name {
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
        type = attrsOf (submodule (dataset config));
        description = "Datasets in this zpool";
        default = { };
      };

      _mkPool = mkOption {
        type = lines;
        default = ''
          zpool create                       \
            ${joinOpts "o" config.poolOpts}  \
            ${joinOpts "O" config.rootOpts}  \
            "${config.name}"                 \
            ${zpoolDevices config}
          ${getEntries (d: d._mkDS) (slashSort config.datasets)}
        '';
      };
    };
  };

  dataset = pool: { name, config, ... }: {
    options = {
      name = mkOption {
        type = str;
        description = "Name of the dataset";
        default = name;
      };
      mountpoint = mkOption {
        type = nullOr path;
        description = "Mount point of the dataset";
        default =
          let res = builtins.match "[^/]+(/.*)" config.name; in
          if res != null then builtins.head res else null;
      };
      options = mkOption {
        type = attrsOf str;
        description = "Options of the dataset";
        default = { };
      };

      _mkDS = mkOption {
        type = lines;
        default = ''
          zfs create                        \
            ${joinOpts "o" config.options}  \
            "${pool.name}/${config.name}"
        '';
      };
    };
  };
in
{
  options.aquaris.filesystem = mkOption {
    type = types.submoduleWith {
      specialArgs = {
        inherit (partitionContent) filesystem;
        zpool = f: partitionContent.zpool (f cfg.zpools);
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

          tools = mkOption {
            type = listOf package;
            description = "Extra tools available to the generated scripts";
            default = with pkgs; [ dosfstools zfs ];
          };

          _format = mkOption {
            type = lines;
            default = ''
              set -x
              ${getEntriesA (d: d._format) cfg.disks}
              ${getEntriesA (p: p._mkPool) cfg.zpools}
            '';
          };

          _formatter = mkOption {
            type = package;
            default = pkgs.writeShellApplication {
              name = "aquaris-formatter";
              runtimeInputs = [ pkgs.util-linux ] ++ cfg.tools;
              text = cfg._format;
            };
          };
        };
      }];
    };
  };
}
