{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.darwin.follows = "";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    und.url = "github:42loco42/und";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      nixosModules = import ./lib/nixosModules.nix { inherit self nixpkgs; };
      lib.aquarisSystems = import ./lib/aquarisSystems.nix { inherit inputs nixosModules; };
    in
    { inherit nixosModules lib; }
    // lib.aquarisSystems ./example
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
