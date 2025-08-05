{ config, lib, ... }:
let
  inherit (lib)
    filterAttrs
    flatten
    mapAttrs'
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    recursiveUpdate
    ;
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
    };

    fileSystems = pipe cfg.dirs [
      (filterAttrs (_: x: x.e))
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
          options = [ "nosuid" "mode=755" ];
        };
      })
    ];

    systemd.tmpfiles.settings = pipe config.aquaris.users [
      (mapAttrs' (n: _:
        let
          user = config.users.users.${n};
          root = "${cfg.root}/${user.home}";

          ug = x: x // {
            user = user.name;
            inherit (user) group;
          };

          mkEntry = d: x:
            let
              mkParents = file:
                if file == "/" || file == "." then [ ]
                else mkParents (dirOf file) ++ [ file ];

              parents = mkParents (dirOf d);

              mkIn = pfx: (map (x: {
                "${pfx}/${x}".d = ug { mode = "0755"; };
              })) parents;
            in
            (mkIn root) ++ (mkIn user.home) ++ [{
              "${root}/${d}".d = ug { mode = x.m; };
              "${user.home}/${d}"."L+".argument = "${root}/${d}";
            }];
        in
        {
          name = "aquaris-persist-user-${n}";
          value = pipe config.home-manager.users.${n}.aquaris.persist [
            (filterAttrs (_: x: x.e))
            (mapAttrsToList mkEntry)
            (x: x ++ [{
              ${root}.d = ug { mode = "0700"; };
            }])
            flatten
            (builtins.foldl' recursiveUpdate { })
          ];
        }))
      (x: x // {
        aquaris-persist-system = pipe cfg.dirs [
          (filterAttrs (_: x: x.e))
          (mapAttrs' (d: x: {
            name = "${cfg.root}/${d}";
            value.d = {
              mode = x.m;
              user = x.u;
              group = x.g;
            };
          }))
        ];
      })
    ];
  };
}
