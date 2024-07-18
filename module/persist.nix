{ config, lib, ... }:
let
  inherit (lib)
    ifEnable
    mapAttrsToList
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
    aquaris.persist.dirs = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/log"
    ] ++
    ifEnable config.networking.networkmanager.enable [
      { d = "/etc/NetworkManager/system-connections"; m = "0700"; }
      { d = "/var/lib/NetworkManager"; m = "0755"; }
    ] ++
    ifEnable config.security.sudo.enable [
      { d = "/var/db/sudo"; m = "0711"; }
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

    systemd.tmpfiles.rules = pipe config.aquaris.users [
      (mapAttrsToList (n: x:
        let u = config.users.users.${n}; in
        pipe x.persist [
          (map (y: [
            "d ${cfg.root}/${u.home}/${y} 0755 ${n} ${u.group} - -"
            "L ${u.home}/${y} - - - - ${cfg.root}/${u.home}/${y}"
          ]))
          builtins.concatLists
          (x: [ "d ${cfg.root}/${u.home} 0700 ${n} ${u.group} - -" ] ++ x)
        ]))
      builtins.concatLists
      (x: map (x: "d ${cfg.root}/${x.d} ${x.m} ${x.u} ${x.g} - -") cfg.dirs ++ x)
    ];
  };
}
