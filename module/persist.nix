{ config, lib, ... }:
let
  inherit (lib)
    flip
    ifEnable
    mapAttrsToList
    mkIf
    mkOption
    pipe
    unique
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

    userDirs = mkOption {
      description = "Default list of persistent user directories";
      type = listOf str;
    };
  };

  config = mkIf cfg.enable {
    aquaris.persist = {
      dirs = [
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/log"
      ] ++ ifEnable config.networking.networkmanager.enable [
        { d = "/etc/NetworkManager/system-connections"; m = "0700"; }
        { d = "/var/lib/NetworkManager"; m = "0755"; }
      ] ++ ifEnable config.security.sudo.enable [
        { d = "/var/db/sudo"; m = "0711"; }
      ] ++ ifEnable config.services.caddy.enable [
        "/var/lib/caddy"
      ] ++ ifEnable config.services.tailscale.enable [
        { d = "/var/lib/tailscale"; m = "0700"; }
      ] ++ ifEnable config.virtualisation.libvirtd.enable [
        "/var/lib/libvirt"
      ] ++ ifEnable config.virtualisation.podman.enable [
        "/var/lib/containers"
      ];

      userDirs =
        ifEnable config.programs.zsh.enable [ ".cache/zsh" ];
    };

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

    systemd.tmpfiles.rules =
      let
        allParents = file:
          if file == "/" || file == "." then [ ]
          else allParents (dirOf file) ++ [ file ];

        mkPersist = x: x // { d = "${cfg.root}/${x.d}"; };
        mkDir = x: "d ${x.d} ${x.m} ${x.u} ${x.g} - -";
        mkDirP = x: mkDir (mkPersist x);

        mkUserDir = u: d:
          let
            mkIn = pfx: map (x: mkDir {
              d = "${pfx}/${x}";
              m = "0755";
              u = u.name;
              g = u.group;
            });

            persistDirs = pipe d [
              allParents
              (mkIn "${cfg.root}/${u.home}")
            ];

            targetDirs = pipe d [
              dirOf
              allParents
              (mkIn u.home)
            ];

            link = let hd = "${u.home}/${d}"; in [
              "L+ ${hd} - ${u.name} ${u.group} - ${cfg.root}/${hd}"
            ];
          in
          persistDirs ++ targetDirs ++ link;

        system = map mkDirP cfg.dirs;

        homes = pipe config.aquaris.users [
          (mapAttrsToList (n: _: config.users.users.${n}))
          (map (flip pipe [
            (x: {
              d = x.home;
              m = "0700";
              u = x.name;
              g = x.group;
            })
            mkDirP
          ]))
        ];

        users = pipe config.aquaris.users [
          (mapAttrsToList (n: x:
            let u = config.users.users.${n}; in
            pipe x.persist [
              (x: x ++ cfg.userDirs)
              (map (mkUserDir u))
              builtins.concatLists
            ]
          ))
          builtins.concatLists
        ];
      in
      unique (system ++ homes ++ users);
  };
}
