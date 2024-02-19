{
  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      nixosModules = import ./lib/nixosModules.nix { inherit self nixpkgs; };
      lib = {
        secretsHelper = import ./lib/secretsHelper.nix;
        aquarisSystems = import ./lib/aquarisSystems.nix
          { aquaris = self; inherit inputs nixosModules; };
      };
    in
    {
      inherit nixosModules lib;
      templates.default = {
        path = ./template;
        description = "Blank Aquaris config flake";
      };
    }
    // lib.aquarisSystems self
    // (
      let
        system = "x86_64-linux";
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.${system} = {
          installer = pkgs.writeShellApplication {
            name = "aquaris-installer";

            runtimeInputs = with pkgs; [
              git
              nix-output-monitor
              nvd
            ];

            text =
              let cfg = self.outputs.nixosConfigurations.castor.config; in
              builtins.readFile (pkgs.substituteAll {
                src = ./lib/combined.sh;
                inherit self;
                name = "castor";
                subs = cfg.nix.settings.substituters;
                keys = cfg.nix.settings.trusted-public-keys;
                masterKeyPath = cfg.aquaris.machine.secretKey;
              });
          };

          aqs = pkgs.writeShellApplication {
            name = "aqs";
            text = builtins.readFile ./lib/aqs.sh;
            runtimeInputs = with pkgs; [
              age
              jq
              nix
            ];
          };
        };

        devShells.${system}.default = pkgs.mkShell {
          packages = with pkgs; [
            age
            nix-output-monitor
            shfmt
          ];
        };

        aqscfg = import ./lib/aqs.nix nixpkgs (import self);
      }
    );
}
