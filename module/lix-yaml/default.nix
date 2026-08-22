{ lib, pkgs, ... }:
let
  inherit (lib.fileset) toSource unions;

  plugin = pkgs.stdenv.mkDerivation {
    pname = "lix-yaml";
    version = "1.0.0";

    src = toSource {
      root = ./.;
      fileset = unions [
        ./meson.build
        ./plugin.cpp
      ];
    };

    nativeBuildInputs = with pkgs; [
      meson
      ninja
      pkg-config
    ];

    buildInputs = with pkgs; [
      boost
      capnproto
      lix
      yaml-cpp
    ];

    preConfigure = ''
      meson rewrite kwargs set project / version "$version"
    '';

    mesonBuildType = "release";
    mesonFlags = [ "--werror" ];
  };
in
{ nix.settings.plugin-files = [ "${plugin}/lib/liblix-yaml.so" ]; }
