{ pkgs, lib, ... }:
let
  # we can't use pkgs here, this would create infinite recursion!
  lanza = import (builtins.fetchGit {
    url = "https://github.com/nix-community/lanzaboote";
    rev = "64b903ca87d18cef2752c19c098af275c6e51d63"; # v0.3.0
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
