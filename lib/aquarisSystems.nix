{ inputs, nixosModules }: src:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs.lib)
    getExe
    mapAttrsToList
    nixosSystem
    pipe;

  utils = import ./utils.nix inputs;
  inherit (utils) recMerge substituteAll;

  globalF = f: recMerge (mapAttrsToList f ((import src).machines));
  packagesF = f: recMerge (map f [ "x86_64-linux" ]);

  out = globalF (name: cfg:
    let
      nixosConfig = let system = cfg.system or "x86_64-linux"; in nixosSystem {
        inherit system;

        specialArgs = inputs // {
          inherit src system;
          inherit (utils) my-utils;
        };

        modules = builtins.attrValues nixosModules ++
          (
            let d = "${src}/machines/${name}"; in
            if !builtins.pathExists d then [ ] else
            pipe d [
              builtins.readDir
              builtins.attrNames
              (map (i: import "${d}/${i}"))
            ]
          ) ++
          [{
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
      };

      installer = pkgs: pkgs.writeShellApplication {
        name = "${name}-installer";
        runtimeInputs = with pkgs; [
          git
          gptfdisk
          inputs.disko.packages.${system}.disko
          jq
          nix-output-monitor
        ];
        text = substituteAll ./installer.sh {
          inherit src name;
          disk = nixosConfig.config.disko.devices.disk.root.device;
          keypath = nixosConfig.config.aquaris.machine.secretKey;
          keys = nixosConfig.config.nix.settings.trusted-public-keys;
          subs = nixosConfig.config.nix.settings.substituters;
        };
      };

      deployer = pkgs: pkgs.writeShellApplication {
        name = "${name}-deployer";
        runtimeInputs = with pkgs; [
          git
          openssh
        ];
        text = substituteAll ./deployer.sh {
          inherit name;
          installer = getExe (installer pkgs);
        };
      };
    in
    {
      nixosConfigurations.${name} = nixosConfig;
      packages = packagesF (system:
        let pkgs = import nixpkgs { inherit system; }; in {
          ${system} = {
            "${name}-installer" = installer pkgs;
            "${name}-deployer" = deployer pkgs;
          };
        });
    });
in
{ inherit (out) nixosConfigurations packages; }
