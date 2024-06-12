{ pkgs, lib, ... }:
let
  # pin exactly this version since it's cached
  lanza041 = builtins.getFlake "github:nix-community/lanzaboote/b627ccd97d0159214cee5c7db1412b75e4be6086?narHash=sha256-eSZyrQ9uoPB9iPQ8Y5H7gAmAgAvCw3InStmU3oEjqsE%3D";
in
{
  imports = [ lanza041.nixosModules.lanzaboote ];

  boot = {
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
      package = lib.mkForce (pkgs.writeShellScriptBin "lzbt" ''
        [ -e /etc/secureboot/keys ] || ${pkgs.sbctl}/bin/sbctl create-keys
        exec ${lanza041.packages.${pkgs.system}.tool}/bin/lzbt "$@"
      '');
    };
  };
}
