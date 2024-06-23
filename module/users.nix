{ config, lib, ... }:
let
  inherit (lib) ifEnable mkDefault mkOption;
  inherit (lib.types) attrsOf bool listOf nullOr str submodule;
  cfg = config.aquaris.users;
in
{
  options.aquaris.users = mkOption {
    description = "User accounts of this configuration";
    type = attrsOf (submodule ({ name, config, ... }: {
      options = {
        description = mkOption {
          description = "A longer description of the username, e.g. the full name";
          type = str;
          default = "";
        };

        admin = mkOption {
          description = "Grant this user sudo rights?";
          type = bool;
          default = false;
        };

        key = mkOption {
          description = "SSH public key of this user";
          type = nullOr str;
          default = null;
        };

        extraKeys = mkOption {
          description = "Extra SSH public keys that can login as this user";
          type = listOf str;
          default = [ ];
        };

        # TODO maybe re-add git identity config?
      };
    }));
    default = { };
  };

  config = {
    users.mutableUsers = false;

    users.users = builtins.mapAttrs
      (name: config: {
        extraGroups = ifEnable config.admin [ "wheel" ];

        isNormalUser = mkDefault true;

        openssh.authorizedKeys.keys =
          ifEnable (! isNull config.key) [ config.key ] ++
          config.extraKeys;
      })
      cfg;
  };
}
