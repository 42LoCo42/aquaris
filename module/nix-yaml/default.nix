{ lib, pkgs, ... }:
let
  inherit (lib.fileset) toSource unions;

  plugin = pkgs.stdenv.mkDerivation {
    pname = "nix-yaml";
    version = "1.2.0";

    src = toSource {
      root = ./.;
      fileset = unions [
        ./meson.build
        ./src
      ];
    };

    __structuredAttrs = true;
    strictDeps = true;

    nativeBuildInputs = with pkgs; [
      meson
      ninja
      pkg-config
    ];

    buildInputs = with pkgs; [
      boost
      capnproto
      lixPackageSets.lix_2_96.lix
      nix
      yaml-cpp
    ];

    preConfigure = ''
      meson rewrite kwargs set project / version "$version"
    '';

    mesonBuildType = "release";
    mesonFlags = [ "--werror" ];
  };
in
{ nix.settings.plugin-files = [ "${plugin}/lib/libyaml.so" ]; }
