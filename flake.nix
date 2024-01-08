{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.darwin.follows = "";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

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
          { inherit inputs nixosModules; };
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
        devShells.${system}.default = pkgs.mkShell {
          packages = with pkgs; [
            nix-output-monitor
            shfmt
          ];
        };
      }
    );
}
