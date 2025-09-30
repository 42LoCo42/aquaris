{ pkgs, config, lib, aquaris, ... }:
let
  inherit (lib) getExe ifEnable mapAttrs' mkDefault mkIf mkMerge mkOption pipe;
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

  mkCreateScript = inputs: getExe (pkgs.writeShellApplication {
    name = "${aquaris.name}-create${if inputs == [] then "-nodeps" else ""}";
    runtimeInputs = inputs;
    text = ''
      set -x
      ${getEntries (x: x._create) cfg.disks}
      ${getEntries (x: x._create) cfg.lvm}
      ${getEntries (x: x._create) cfg.zpools}
    '';
  });

  mkMountScript = inputs: getExe (pkgs.writeShellApplication {
    name = "${aquaris.name}-mount${if inputs == [] then "-nodeps" else ""}";
    runtimeInputs = inputs;
    text = aquaris.lib.subsT ./mount.sh {
      fstab = config.environment.etc.fstab.source;
      inherit (config.aquaris.secrets) key;
    };
  });
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
    mkMerge [
      {
        aquaris.filesystems.tools = with pkgs; [
          cryptsetup
          e2fsprogs
        ];

        boot.initrd.luks.devices = mounts.luks or { };
        fileSystems = mounts.fileSystems or { };
        swapDevices = mounts.swapDevices or [ ];

        system.build = rec {
          formatScript = mkCreateScript cfg.tools;
          mountScript = mkMountScript cfg.tools;
          diskoScript = pkgs.writeShellScript "${aquaris.name}-disko" ''
            set -e
            ${formatScript}
            ${mountScript}
          '';

          formatScriptNoDeps = mkCreateScript [ ];
          mountScriptNoDeps = mkMountScript [ ];
          diskoScriptNoDeps = pkgs.writeShellScript "${aquaris.name}-disko-nodeps" ''
            set -e
            ${formatScriptNoDeps}
            ${mountScriptNoDeps}
          '';
        };
      }

      (mkIf config.boot.zfs.enabled {
        services.zfs = {
          autoScrub.enable = mkDefault true;
          autoSnapshot.enable = mkDefault true;
          trim.enable = mkDefault true;
        };

        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "zfsnaps";
            text = builtins.readFile ./zfsnaps.sh;
          })
        ];
      })
    ];
}
