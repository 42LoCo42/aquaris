{
  outputs = { self, nixpkgs }:
    let
      lib = import ./lib.nix self.inputs;
      main = import ./main.nix { inherit self lib nixpkgs; };

      out = {
        inherit lib;
        __functor = _: main;
      };
    in
    out // out self
      # shared config passed as aquaris.cfg to every machine
      # here used for shared user templates
      {
        users = rec {
          alice = {
            key = "foo";
          };

          bob = {
            key = "bar";
            extraKeys = [ alice.key ];
          };
        };
      };
}
