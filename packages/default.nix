{ lib, nixpkgs }: lib.eachDefaultSystem (system:
let pkgs = import nixpkgs { inherit system; }; in {
  packages = {
    aqs = import ./aqs pkgs;
  };
})
