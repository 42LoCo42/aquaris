{
  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    obscura.url = "github:42loco42/obscura";
  };

  outputs = { self, nixpkgs, ... }:
    let
      lib = import ./lib nixpkgs;

      out = {
        inherit lib;
        __functor = _: import ./lib/main.nix { inherit self lib nixpkgs; };
      } // import ./packages { inherit lib nixpkgs; };

      example = out self {
        # shared config passed as aquaris.cfg to every machine
        users = {
          dev = {
            description = "Example user";
            sshKeys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVieLCkWGImVI9c7D0Z0qRxBAKf0eaQWUfMn0uyM/Ql"
            ];

            git = {
              name = "John E. Xample"; # if unset, falls back to user description or null
              email = "dev@example.org";
              key = "5FD475844A801467A76A2BC1F8BFE9665DC06BBB";
            };
          };
        };
      };
    in
    lib.merge [ out example ];
}
