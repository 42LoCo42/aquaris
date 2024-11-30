lib: nixpkgs:
lib.eachDefaultSystem (system:
let pkgs = import nixpkgs { inherit system; }; in {
  packages = {
    deploy = import ./deploy nixpkgs pkgs lib;
  };
})
