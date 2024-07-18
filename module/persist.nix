{ pkgs, config, lib, ... }:
let
  inherit (lib)
    getExe
    ifEnable
    mkIf
    mkOption
    pipe
    ;
  inherit (lib.types)
    bool
    coercedTo
    listOf
    path
    str
    submodule
    ;

  cfg = config.aquaris.persist;

  entry = submodule {
    options = {
      d = mkOption {
        description = "Directory";
        type = path;
      };

      m = mkOption {
        description = "Mode";
        type = str;
        default = "0755";
      };

      u = mkOption {
        description = "User/UID";
        type = str;
        default = "root";
      };

      g = mkOption {
        description = "Group/GID";
        type = str;
        default = "root";
      };
    };
  };

  persist-setup = pkgs.writeShellApplication {
    name = "persist-setup";
    text = pipe cfg.dirs [
      (map (x: ''
        chown "${x.u}:${x.g}" "${x.d}"
        chmod "${x.m}"        "${x.d}"
      ''))
      (builtins.concatStringsSep "\n")
    ];
  };
in
{
  options.aquaris.persist = {
    enable = mkOption {
      description = "Enable the persistency manager for tmpfs-on-/";
      type = bool;
      default = false;
    };

    root = mkOption {
      description = "Path to persistent root";
      type = path;
      default = if cfg.enable then "/persist" else "/";
    };

    dirs = mkOption {
      description = "List of persistent directories";
      type = listOf (coercedTo path (d: { inherit d; }) entry);
    };
  };

  config = mkIf cfg.enable {
    aquaris.persist.dirs = builtins.filter (x: x != null) [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"

      (ifEnable config.networking.networkmanager.enable "/var/lib/NetworkManager")
      (ifEnable config.security.sudo.enable { d = "/var/db/sudo"; m = "0711"; })
    ];

    fileSystems = pipe cfg.dirs [
      (map (x: {
        name = x.d;
        value = {
          device = "${cfg.root}/${x.d}";
          options = [
            "bind"
            "x-aquaris.persist=${x.m}"
          ];
        };
      }))
      builtins.listToAttrs
      (x: x // {
        ${cfg.root}.neededForBoot = true;

        "/" = {
          fsType = "tmpfs";
          options = [ "mode=755" ];
        };
      })
    ];

    system.activationScripts.persist-setup = getExe persist-setup;
  };
}
