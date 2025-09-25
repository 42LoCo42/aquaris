{ pkgs, lib, config, aquaris, ... }@top:
let
  inherit (lib)
    flip
    getExe
    hasPrefix
    makeBinPath
    mapAttrs'
    mkBefore
    mkForce
    mkIf
    mkMerge
    mkOption
    pipe
    splitString
    zipAttrs
    ;

  inherit (lib.types)
    attrsOf
    coercedTo
    lines
    listOf
    nullOr
    package
    path
    str
    submodule
    ;

  inherit (config.aquaris) secret;

  join = builtins.concatStringsSep " ";

  empty = pkgs.dockerTools.buildImage {
    name = "empty";
    tag = "latest";
  };

  container = { name, config, ... }: {
    options = {
      ##### entrypoint #####

      cmd = mkOption { type = listOf str; };

      script = mkOption {
        type = nullOr lines;
        description = "Optional shell script to use as entrypoint";
        default = null;
      };

      path = mkOption {
        type = listOf package;
        description = "Packages available to the script";
        default = [ ];
      };

      ##### inherited #####

      environment = mkOption {
        type = attrsOf str;
        default = { };
      };

      environmentFiles = mkOption {
        type = listOf path;
        default = [ ];
      };

      extraOptions = mkOption {
        type = listOf str;
        default = [ ];
      };

      ports = mkOption {
        type = listOf str;
        default = [ ];
      };

      volumes = mkOption {
        type = listOf str;
        default = [ ];
      };

      workdir = mkOption {
        type = nullOr str;
        default = null;
      };

      ##### special args #####

      ca = mkOption {
        description = "Path to the TLS certificate bundle";
        type = path;
        default = top.config.security.pki.caBundle;
      };

      extraOptionsRaw = mkOption {
        description = "Unescaped arguments to podman";
        type = listOf str;
        default = [ ];
      };

      secrets = mkOption {
        description = ''
          List of <host path>:<container path> of secrets to mount

          Instead of the host path (which must be absolute),
          the name of an Aquaris-managed secret can also be given.
        '';
        type = coercedTo
          (listOf str)
          (map (x:
            let parts = splitString ":" x; in
            assert builtins.length parts == 2; rec {
              host = pipe parts [
                (flip builtins.elemAt 0)
                (x: if hasPrefix "/" x then x else secret x)
              ];

              cont = builtins.elemAt parts 1;

              name = builtins.hashString "sha256" host;
            }))
          (listOf (submodule {
            options = {
              host = mkOption { type = path; };
              cont = mkOption { type = path; };
              name = mkOption { type = str; };
            };
          }));
        default = [ ];
      };
    };

    config = {
      cmd = mkIf (config.script != null) (mkForce [
        (getExe (pkgs.writeShellApplication {
          name = "${name}-start";
          runtimeInputs = config.path;
          text = config.script;
        }))
      ]);

      environment.PATH = mkIf (config.path != [ ]) (makeBinPath config.path);

      volumes = [
        "${config.ca}:/etc/pki/tls/certs/ca-bundle.crt:ro"
        "${config.ca}:/etc/ssl/certs/ca-bundle.crt:ro"
        "${config.ca}:/etc/ssl/certs/ca-certificates.crt:ro"
      ];

      extraOptions = [
        "--read-only"
        "--tmpfs=/tmp"
        "--tz=${top.config.time.timeZone}"
      ];

      extraOptionsRaw = mkMerge [
        [
          ''--user="$CUID:$CGID"''
          ''--passwd-entry="${name}:x:$CUID:$CGID:${name}:/:/bin/sh"''
          ''--group-entry="${name}:x:$CGID:"''
        ]

        ((flip map config.secrets)
          (x: ''-v "''${CREDENTIALS_DIRECTORY}/${x.name}:${x.cont}:ro"''))
      ];
    };
  };

  deps = name: cfg: pipe { inherit (cfg) cmd environment volumes; } [
    builtins.toJSON
    (pkgs.writeText "${name}-info")
    (info: (pkgs.runCommand "${name}-volumes" {
      __structuredAttrs = true;
      exportReferencesGraph.graph = info;
      nativeBuildInputs = with pkgs; [ jq ];
    }) ''
      jq -r '
        .graph
        | map(.path)
        | sort
        | .[]
      ' "$NIX_ATTRS_JSON_FILE" \
      | grep -v "${info}"      \
      | sed -E 's|(.*)|-v \1:\1:ro|' > $out
    '')
  ];

  cfg = config.virtualisation.pnoc;
in
{
  options.virtualisation.pnoc = mkOption {
    type = attrsOf (submodule container);
    default = { };
  };

  config = {
    users = pipe cfg [
      builtins.attrNames
      (map (x: {
        users.${x} = {
          group = x;
          isSystemUser = true;
        };
        groups.${x} = { };
      }))
      aquaris.lib.merge
    ];

    systemd.services = flip mapAttrs' cfg (name: cfg: {
      name = "podman-${name}";
      value = mkMerge [
        {
          script = mkBefore ''
            CUID="$(id -u "${name}")"
            CGID="$(id -g "${name}")"
          '';
        }

        (mkIf (cfg.secrets != [ ]) {
          serviceConfig = pipe cfg.secrets [
            (map (x: { LoadCredential = "${x.name}:${x.host}"; }))
            zipAttrs
          ];

          script = mkBefore ''
            ${pkgs.util-linux}/bin/mount -v -o remount,rw "''${CREDENTIALS_DIRECTORY}"

            ${join (map (x: ''
              ${pkgs.coreutils}/bin/chown -v ${name} "''${CREDENTIALS_DIRECTORY}/${x.name}"
            '') cfg.secrets)}

            ${pkgs.util-linux}/bin/mount -v -o remount,ro "''${CREDENTIALS_DIRECTORY}"
          '';
        })
      ];
    });

    virtualisation = {
      podman = {
        package = pkgs.podman // { override = _: pkgs.podman; };
        defaultNetwork.settings = {
          dns_enabled = true;
          ipv6_enabled = true;
          subnets = [
            {
              subnet = "10.88.0.0/16";
              gateway = "10.88.0.1";
            }
            {
              subnet = "fd00::/80";
              gateway = "fd00::1";
            }
          ];
        };
      };

      oci-containers.containers = flip builtins.mapAttrs cfg (name: cfg: {
        inherit (cfg)
          cmd
          environment
          environmentFiles
          extraOptions
          ports
          volumes
          workdir
          ;

        image = join [
          (join cfg.extraOptionsRaw)
          "$(< ${deps name cfg})"
          "${empty.imageName}:${empty.imageTag}"
        ];

        imageFile = empty;
      });
    };
  };
}
