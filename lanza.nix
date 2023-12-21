system: { pkgs, lib, nixpkgs, ... }:
let
  # we have to import nixpkgs here to break a recursion cycle
  fresh-pkgs = import nixpkgs { inherit system; };
  lanza = import (fresh-pkgs.fetchFromGitHub {
    owner = "nix-community";
    repo = "lanzaboote";
    rev = "v0.3.0";
    hash = "sha256-Fb5TeRTdvUlo/5Yi2d+FC8a6KoRLk2h1VE0/peMhWPs=";
  });
in
{
  imports = [ lanza.nixosModules.lanzaboote ];

  boot = {
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
      package = lib.mkForce (pkgs.writeShellScriptBin "lzbt" ''
        [ -e /etc/secureboot/keys ] || ${pkgs.sbctl}/bin/sbctl create-keys
        exec ${lanza.packages.${pkgs.system}.lzbt}/bin/lzbt "$@"
      '');
    };
  };
}
