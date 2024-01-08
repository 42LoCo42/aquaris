{ config, lib, my-utils, ... }:
let
  inherit (lib) concatMapStringsSep mkOption pipe types;
  inherit (types) attrsOf listOf path str;
  cfg = config.aquaris.persistence;
in
{
  options.aquaris.persistence = {
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

  config = {
    aquaris.persistence.system = [
      "/etc/secureboot"
      "/var/db/sudo"
      "/var/log"
    ];

    fileSystems.${cfg.root}.neededForBoot = true;

    system.activationScripts.aquaris-persistence.text =
      concatMapStringsSep "\n"
        (path: ''
          mkdir -p ${cfg.root}/${path}
          findmnt ${path} >/dev/null || mount -Bm ${cfg.root}/${path} ${path}
        '')
        cfg.system;

    home-manager.users = builtins.mapAttrs
      (_: paths: { ... }@hm: {
        home.activation.aquaris-persistence = pipe paths [
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
