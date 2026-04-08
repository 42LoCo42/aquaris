{ self, pkgs, lib, config, ... }:
let
  inherit (lib)
    mkDefault
    mkForce
    mkIf
    mkMerge
    ;

  mach = config.aquaris.machine;
  lzbt = config.boot.lanzaboote;

  pcrlockDir = "/var/lib/pcrlock.d";
in
{
  imports = [ self.inputs.obscura.nixosModules.lanzaboote ];

  assertions = [{
    assertion = lzbt.measuredBoot.pcrlockDirectory == pcrlockDir;
    message = ''
      lanzaboote: pcrlockDirectory can't be changed,
      since some systemd-pcrlock measurements hardcode it to /var/lib/pcrlock.d!
    '';
  }];

  aquaris.persist.dirs = mkMerge [
    (mkIf lzbt.measuredBoot.enable {
      ${lzbt.measuredBoot.pcrlockDirectory} = { };
    })

    (mkIf lzbt.measuredBoot.autoCryptenroll.enable {
      "/var/lib/auto-cryptenroll" = { };
    })
  ];

  boot = {
    lanzaboote = {
      enable = mkDefault mach.secureboot;
      package = mkForce self.inputs.obscura.packages.${pkgs.stdenv.system}.lanzaboote.lzbt;
      pkiBundle = mkForce "${config.aquaris.persist.root}/var/lib/sbctl";

      autoGenerateKeys.enable = true;

      autoEnrollKeys = {
        enable = mkDefault true;
        autoReboot = mkDefault true;
      };

      measuredBoot = {
        enable = mkDefault true;
        pcrs = mkDefault [ 0 1 2 3 4 7 ];

        pcrlockDirectory = mkForce pcrlockDir;
      };
    };

    loader = {
      efi.canTouchEfiVariables = mkDefault true;
      timeout = mkDefault 0;

      systemd-boot = {
        enable = mkDefault (! mach.secureboot);
        configurationLimit = mach.keepGenerations;
        editor = mkDefault false;
      };
    };
  };

  environment.etc."sbctl/sbctl.conf".text = mkForce ''
    bundles_db: ${lzbt.pkiBundle}/bundles.json
    files_db:   ${lzbt.pkiBundle}/files.json
    guid:       ${lzbt.pkiBundle}/GUID
    keydir:     ${lzbt.pkiBundle}/keys
  '';
}
