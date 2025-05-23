{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    obscura.url = "github:42loco42/obscura";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      lib = import ./lib inputs;

      out = {
        inherit lib;
        __functor = _: import ./lib/main.nix { inherit self lib nixpkgs; };

        templates.default = {
          description = "Aquaris example config template";
          path = ./example;
        };
      } // import ./packages lib nixpkgs;

      # silly hack :3 i'm amazed that this actually works!
      example = (import ./example/flake.nix).outputs {
        aquaris = out;
        self = self // { cfgDir = ./example; };
      };
    in
    lib.merge [ out example ];
}
