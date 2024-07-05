lib: { nixpkgs, relocatable, ... }:
lib.eachDefaultSystem (system:
let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      (_: prev: {
        relocatable = drv: (prev.callPackage relocatable { } drv).overrideAttrs {
          meta.mainProgram = "${drv.name}.deploy";
        };
      })
    ];
  };
in
{
  packages = {
    aqs = import ./aqs pkgs;
    deploy = import ./deploy pkgs lib;
  };
})
