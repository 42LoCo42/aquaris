{ pkgs, config, lib, aquaris, ... }:
let
  inherit (lib) ifEnable mapAttrs' mkDefault mkIf mkMerge mkOption pipe;
  inherit (lib.strings) normalizePath;
  inherit (lib.types) attrsOf listOf package submodule submoduleWith;

  fs = aquaris.lib.adt {
    btrfs = import ./btrfs.nix pkgs;
    ignore = ./ignore.nix;
    luks = import ./luks.nix util;
    lvm = ./lvmMember.nix;
    regular = ./regular.nix;
    swap = ./swap.nix;
    zpool = ./zpoolMember.nix;
  };

  getEntries = f: v: pipe v [
    (v: if builtins.isAttrs v then builtins.attrValues v else v)
    (map f)
    (builtins.concatStringsSep "\n")
  ];

  util = {
    inherit (aquaris.lib) merge;
    inherit fs getEntries;
  };

  cfg = config.aquaris.filesystems;

  options = ifEnable config.services.zfs.autoSnapshot.enable {
    "com.sun:auto-snapshot" = "true";
  };
in
{
  options.aquaris.filesystems = mkOption {
    description = "Declarative filesystem configuration";
    type = submoduleWith {
      specialArgs = {
        fs = fs.mk // {
          ignore = {
            _create = "";
            content = fs.mk.ignore { };
          };

          swap = fs.mk.swap { };

          lvm = f: fs.mk.lvm {
            group = (f cfg.lvm).name;
          };

          zpool = f: fs.mk.zpool {
            pool = (f cfg.zpools).name;
          };

          defaultBoot = {
            type = "uefi";
            size = "512M";
            content = fs.mk.regular {
              type = "vfat";
              mountpoint = "/boot";
            };
          };

          defaultPool.datasets = {
            "nixos/nix" = { };
          } // ifEnable config.aquaris.persist.enable {
            "nixos/persist" = { inherit options; };
          } // mapAttrs'
            (n: x: {
              name = "nixos/home/${n}";
              value = {
                inherit options;
                mountpoint = pipe x.home [
                  (x: "${config.aquaris.persist.root}/${x}")
                  normalizePath
                ];
              };
            })
            config.aquaris.users;
        };
      };

      modules = [{
        options = {
          disks = mkOption {
            type = attrsOf (submodule (import ./disk.nix util));
            default = { };
          };

          lvm = mkOption {
            type = attrsOf (submodule (import ./lvm.nix util));
            default = { };
          };

          zpools = mkOption {
            type = attrsOf (submodule (import ./zpool.nix util));
            default = { };
          };

          tools = mkOption {
            description = "Packages available to the generated scripts";
            type = listOf package;
          };

          _create = mkOption {
            type = package;
            readOnly = true;
            default = pkgs.writeShellApplication {
              name = "${aquaris.name}-create";
              runtimeInputs = cfg.tools;
              text = ''
                set -x
                ${getEntries (x: x._create) cfg.disks}
                ${getEntries (x: x._create) cfg.lvm}
                ${getEntries (x: x._create) cfg.zpools}
              '';
            };
          };

          _mount = mkOption {
            type = package;
            readOnly = true;
            default = pkgs.writeShellApplication {
              name = "${aquaris.name}-mount";
              runtimeInputs = cfg.tools;
              text = aquaris.lib.subsT ./mount.sh {
                fstab = config.environment.etc.fstab.source;
              };
            };
          };
        };
      }];
    };
    default = { };
  };

  config =
    let
      mounts = pipe cfg [
        (x: with x; [ disks lvm zpools ])
        (map (x: pipe x [
          builtins.attrValues
          (map (x: x._mounts))
          util.merge
        ]))
        util.merge
      ];
    in
    {
      aquaris.filesystems.tools = with pkgs; [
        cryptsetup
        e2fsprogs
      ];

      fileSystems = mounts.fileSystems or { };
      swapDevices = mounts.swapDevices or [ ];

      boot = mkMerge [
        (mkIf (config.boot.supportedFilesystems.zfs or false) {
          # TODO latestCompatibleLinuxPackages is deprecated!
          kernelPackages = mkDefault config.boot.zfs.package.latestCompatibleLinuxPackages;
        })
        { initrd.luks.devices = mounts.luks or { }; }
      ];
    };
}
