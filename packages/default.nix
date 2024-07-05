lib: nixpkgs:
lib.eachDefaultSystem (system:
let pkgs = import nixpkgs { inherit system; }; in {
  packages = {
    aqs = import ./aqs pkgs;
    deploy = import ./deploy nixpkgs pkgs lib;
  };
})
