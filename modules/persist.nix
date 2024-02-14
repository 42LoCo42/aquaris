{ config, lib, my-utils, ... }:
let
  inherit (lib) mkIf mkOption pipe types;
  inherit (types) attrsOf bool listOf path str;
  cfg = config.aquaris.persist;
in
{
  options.aquaris.persist = {
    enable = mkOption {
      type = bool;
      default = true;
    };

    root = mkOption {
      type = path;
      description = ''
        Persistent root directory.
        Must be a mountpoint.
      '';
      default = "/persist";
    };

    system = mkOption {
      type = listOf path;
      description = ''
        List of persistent system directories.
        These will be bind-mounted.
      '';
    };

    users = mkOption {
      type = attrsOf (listOf str);
      description = ''
        List of persistent user directories.
        These will be symlinked.
      '';
      default = { };
    };
  };

  config = mkIf cfg.enable {
    aquaris.persist.system = [
      "/etc/secureboot"
      "/var/db/sudo"
      "/var/log"
    ];

    fileSystems = pipe cfg.system [
      (map (path: {
        name = path;
        value = {
          device = "${cfg.root}/${path}";
          options = [ "bind" ];
        };
      }))
      builtins.listToAttrs
    ] // {
      "/" = {
        fsType = "tmpfs";
        options = [ "mode=755" ];
      };

      ${cfg.root}.neededForBoot = true;
    };

    home-manager.users = builtins.mapAttrs
      (_: paths: { ... }@hm: {
        home.activation.aquaris-persist = pipe paths [
          (map (path: {
            src = "${cfg.root}/${hm.config.home.homeDirectory}/${path}";
            dst = "${hm.config.home.homeDirectory}/${path}";
          }))
          my-utils.mkHomeLinks
        ];
      })
      cfg.users;
  };
}
