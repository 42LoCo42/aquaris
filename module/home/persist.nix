{ config, lib, osConfig, ... }:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    ;
  inherit (lib.types) attrsOf bool str submodule;

  ###############################################################
  #  NOTE: actually implemented in ../persist.nix               #
  #  as system-wide `systemd.tmpfiles.settings` config blocks,  #
  #  this module just defines options & defaults!               #
  ###############################################################

  entry = submodule {
    options = {
      e = mkOption {
        description = "Enable";
        type = bool;
        default = true;
      };

      m = mkOption {
        description = "Mode";
        type = str;
        default = "0755";
      };
    };
  };
in
{
  options.aquaris.persist = mkOption {
    description = "List of persistent directories";
    type = attrsOf entry;
  };

  config = mkIf osConfig.aquaris.persist.enable {
    aquaris.persist = mkMerge [
      {
        ".cache/nix" = { };
      }

      (mkIf config.programs.direnv.enable {
        ".local/share/direnv" = { };
      })

      (mkIf config.programs.gpg.enable {
        ".gnupg" = { m = "0700"; };
      })

      (mkIf config.programs.zoxide.enable {
        ".local/share/zoxide" = { };
      })

      (mkIf config.programs.zsh.enable {
        ".cache/zsh" = { };
      })
    ];

    home.shellAliases.eph = "sudo find / -xdev -type f | sort | less";
  };
}
