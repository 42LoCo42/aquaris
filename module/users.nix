{ config, lib, ... }:
let
  inherit (lib) ifEnable mkDefault mkOption;
  inherit (lib.types) attrsOf bool listOf nullOr str submodule;
  cfg = config.aquaris.users;
in
{
  options.aquaris.users = mkOption {
    description = "User accounts of this configuration";
    type = attrsOf (submodule ({ config, ... }: {
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

        sshKeys = mkOption {
          description = "SSH public keys that may log in as this user";
          type = listOf str;
          default = [ ];
        };

        git = {
          name = mkOption {
            description = "Full name of this user for Git";
            type = nullOr str;
            default = if config.description != "" then config.description else null;
          };

          email = mkOption {
            description = "Email of this user for Git";
            type = nullOr str;
            default = null;
          };

          key = mkOption {
            description = "Signing key ID of this user for Git";
            type = nullOr str;
            default = null;
          };
        };

        persist = mkOption {
          description = "List of persistent directories";
          type = listOf str;
          default = [ ];
        };
      };
    }));
    default = { };
  };

  config = {
    users.mutableUsers = false;

    users.users = builtins.mapAttrs
      (name: cfg: {
        inherit (cfg) description;
        extraGroups = ifEnable cfg.admin [ "networkmanager" "wheel" ];
        hashedPasswordFile = config.aquaris.secrets."users/${name}/passwordHash".outPath or null;
        isNormalUser = mkDefault true;
        openssh.authorizedKeys.keys = cfg.sshKeys;
      })
      cfg;
  };
}
