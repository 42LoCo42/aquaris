{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (types) str;
  cfg = config.aquaris.customize;
in
{
  options.aquaris.customize = {
    userName = mkOption {
      type = str;
    };

    publicKey = mkOption {
      type = str;
    };

    keyMap = mkOption {
      type = str;
      default = "de-latin1";
    };

    locale = mkOption {
      type = str;
      default = "en_US.UTF-8";
    };

    timeZone = mkOption {
      type = str;
      default = "Europe/Berlin";
    };
  };

  config = {
    console.keyMap = cfg.keyMap;
    i18n.defaultLocale = cfg.locale;
    time.timeZone = cfg.timeZone;

    users.mutableUsers = false;
    users.users.default = {
      name = cfg.userName;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.age.secrets.password-hash.path;
      openssh.authorizedKeys.keys = [ cfg.publicKey ];
    };
  };
}
