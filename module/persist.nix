{ config, lib, ... }:
let
  inherit (lib) filterAttrs mapAttrsToList mkIf mkMerge mkOption pipe;
  inherit (lib.types) attrsOf bool path str submodule;

  cfg = config.aquaris.persist;

  entry = submodule {
    options = {
      e = mkOption {
        description = "Enable";
        type = bool;
        default = true;
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
      type = attrsOf entry;
    };

    dirs' = mkOption {
      description = "List of ENABLED persistent directories";
      type = attrsOf entry;
    };
  };

  config = mkIf cfg.enable {
    aquaris.persist = {
      dirs = mkMerge [
        {
          "/var/lib/systemd" = { };
          "/var/log" = { };
        }

        (mkIf config.networking.networkmanager.enable {
          "/etc/NetworkManager/system-connections" = { m = "0700"; };
          "/var/lib/NetworkManager" = { m = "0755"; };
        })

        (mkIf config.security.sudo.enable {
          "/var/db/sudo" = { m = "0711"; };
        })

        (mkIf config.services.caddy.enable {
          "/var/lib/caddy" = { };
        })

        (mkIf config.services.tailscale.enable {
          "/var/lib/tailscale" = { m = "0700"; };
        })

        (mkIf config.virtualisation.libvirtd.enable {
          "/var/lib/libvirt" = { };
        })

        (mkIf config.virtualisation.podman.enable {
          "/var/lib/containers" = { };
        })
      ];

      dirs' = filterAttrs (_: x: x.e) cfg.dirs;
    };

    fileSystems = pipe cfg.dirs' [
      (builtins.mapAttrs (d: x: {
        device = "${cfg.root}/${d}";
        options = [
          "bind"
          "x-aquaris.persist=${x.m}"
        ];
      }))

      (x: x // {
        ${cfg.root}.neededForBoot = true;

        "/" = {
          fsType = "tmpfs";
          options = [ "mode=755" ];
        };
      })
    ];

    systemd.tmpfiles.rules =
      let
        system = mapAttrsToList
          (d: x: "d ${cfg.root}/${d} ${x.m} ${x.u} ${x.g} - -")
          cfg.dirs';

        homes = pipe config.aquaris.users [
          (mapAttrsToList (n: _: config.users.users.${n}))
          (map (x: "d ${cfg.root}/${x.home} 0700 ${x.name} ${x.group} - -"))
        ];
      in
      system ++ homes;
  };
}
