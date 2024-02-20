{ aquaris, inputs, nixosModules }:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs.lib) nixosSystem pipe;

  inherit (import ./utils.nix inputs) my-utils;

  wrap = f: inputs.flake-utils.lib.eachDefaultSystem
    (system: f (import nixpkgs { inherit system; }));

  mkAQS = pkgs: pkgs.writeShellApplication {
    name = "aqs";
    text = builtins.readFile ./aqs.sh;
    runtimeInputs = with pkgs; [
      age
      jq
      nix
    ];
  };

  setup = wrap (pkgs:
    let aqs = mkAQS pkgs; in {
      packages = {
        inherit aqs;
        default = pkgs.writeShellApplication {
          name = "aquaris-setup";
          text = my-utils.subsT ./setup/setup.sh { src = ./setup; };
          runtimeInputs = with pkgs; [
            age # to encrypt secrets
            aqs # to fix encryption
            gettext # for template instantiation
            mkpasswd # for creating a password hash
            nixpkgs-fmt # for pretty-printing the generated flake
            systemdMinimal # for machine ID creation
          ];
        };
      };

      devShells.default = pkgs.mkShell {
        packages = with pkgs; [ age aqs ];
      };
    });

  main = self: aqscfg:
    wrap (pkgs: { packages.aqs = mkAQS pkgs; }) // {
      inherit aqscfg;
      nixosConfigurations = builtins.mapAttrs
        (name: cfg:
          let system = cfg.system or "x86_64-linux"; in nixosSystem {
            inherit system;

            specialArgs = inputs // {
              inherit
                aquaris
                my-utils
                name
                self
                system;
            };

            modules = builtins.attrValues nixosModules ++ (
              let d = "${self}/machines/${name}"; in
              if !builtins.pathExists d then [ ] else
              pipe d [
                builtins.readDir
                builtins.attrNames
                (map (i: import "${d}/${i}"))
              ]
            ) ++ [{
              aquaris = {
                # merge admins and users
                users = builtins.mapAttrs (_: u: u // { isAdmin = true; })
                  (cfg.admins or { }) // (cfg.users or { });

                machine = {
                  inherit name;
                  inherit (cfg) id publicKey;
                };
              };
            }];
          })
        aqscfg.machines;
    };
in
{ inherit setup main; }

# TODO remove dead code
#       installer = pkgs: pkgs.writeShellApplication {
#         name = "${name}-installer";
#         runtimeInputs = with pkgs; [
#           git
#           gptfdisk
#           jq
#           nix-output-monitor
#         ];
#         text = subsT ./installer.sh {
#           inherit name self;
#           keypath = nixosConfig.config.aquaris.machine.secretKey;
#           keys = nixosConfig.config.nix.settings.trusted-public-keys;
#           subs = nixosConfig.config.nix.settings.substituters;
#         };
#       };

#       deployer = pkgs: pkgs.writeShellApplication {
#         name = "${name}-deployer";
#         runtimeInputs = with pkgs; [
#           git
#           openssh
#         ];
#         text = subsT ./deployer.sh {
#           inherit name;
#           installer = getExe (installer pkgs);
#         };
#       };
