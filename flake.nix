{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    obscura.url = "github:42loco42/obscura";

    sillysecrets.url = "github:42loco42/sillysecrets?rev=1.3.0";
    sillysecrets.inputs.flake-utils.follows = "flake-utils";
    sillysecrets.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs.lib.fileset) difference toSource unions;

      lib = import ./lib inputs;

      out = {
        inherit lib;
        __functor = _: import ./lib/main.nix { inherit self lib nixpkgs; };

        templates.default = {
          description = "Aquaris example config template";

          path = (toSource {
            root = ./example;
            fileset = difference ./example (unions [
              ./example/keys/.gitignore
              ./example/keys/example.key
            ]);
          }).outPath;
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
