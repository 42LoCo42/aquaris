{
  outputs = { self, nixpkgs }@inputs:
    let
      inherit (nixpkgs.lib)
        filterAttrs
        pipe
        ;

      lib = import ./lib.nix inputs;

      out = import ./aqs { inherit lib nixpkgs; } // {
        inherit lib;
        __functor = _: import ./main.nix { inherit self lib nixpkgs; };
      };

      example = out self {
        # shared config passed as aquaris.cfg to every machine
      };
    in
    lib.merge [ out example ];
}
