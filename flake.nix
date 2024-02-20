{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

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
      aqscfg = import ./lib/aqs.nix nixpkgs (import self);
      templates.default = {
        path = ./template;
        description = "Blank Aquaris config flake";
      };
    }
    // lib.aquarisSystems self
    // inputs.flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; }; in rec {
        packages = {
          # castor-installer = pkgs.writeShellApplication {
          #   name = "castor-installer";

          #   runtimeInputs = with pkgs; [
          #     git
          #     nix-output-monitor
          #     nvd
          #   ];

          #   text =
          #     let cfg = self.outputs.nixosConfigurations.castor.config; in
          #     builtins.readFile (pkgs.substituteAll {
          #       src = ./lib/combined.sh;
          #       inherit self;
          #       name = "castor";
          #       subs = cfg.nix.settings.substituters;
          #       keys = cfg.nix.settings.trusted-public-keys;
          #       masterKeyPath = cfg.aquaris.machine.secretKey;
          #     });
          # };

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

        devShells.default = pkgs.mkShell {
          packages = with pkgs; with packages; [
            age
            aqs
            nix-output-monitor
            shfmt
          ];
        };
      });
}
