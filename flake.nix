{
  outputs = { self, nixpkgs }@inputs:
    let
      lib = import ./lib.nix inputs;

      out = import ./aqs { inherit lib nixpkgs; } // {
        inherit lib;
        __functor = _: import ./main.nix { inherit self lib nixpkgs; };
      };

      example = out self {
        # shared config passed as aquaris.cfg to every machine
        users = {
          dev = {
            description = "Example user";
            sshKeys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVieLCkWGImVI9c7D0Z0qRxBAKf0eaQWUfMn0uyM/Ql"
            ];
          };
        };
      };
    in
    lib.merge [ out example ];
}
