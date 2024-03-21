{ obscura, pkgs, lib, ... }: {
  imports = [ obscura.nixosModules.lanzaboote ];

  boot = {
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
      package = lib.mkForce (pkgs.writeShellScriptBin "lzbt" ''
        [ -e /etc/secureboot/keys ] || ${pkgs.sbctl}/bin/sbctl create-keys
        exec ${obscura.packages.${pkgs.system}.my-lzbt}/bin/lzbt "$@"
      '');
    };
  };
}
