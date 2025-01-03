{ config, lib, osConfig, ... }:
let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    pipe
    unique
    ;
  inherit (lib.types) attrsOf bool str submodule;

  cfg = config.aquaris.persist;

  inherit (osConfig.aquaris.persist) root;
  inherit (osConfig.users.users.${config.home.username}) home;

  allParents = file:
    if file == "/" || file == "." then [ ]
    else allParents (dirOf file) ++ [ file ];

  mkIn = pfx: map (x: "d ${pfx}/${x} 0755 - - - -");

  mkEntry = d: x:
    let
      persistDirs = pipe d [
        allParents
        (mkIn "${root}/${home}")
      ];

      targetDirs = pipe d [
        dirOf
        allParents
        (mkIn home)
      ];

      final = let hd = "${home}/${d}"; in [
        "z ${root}/${hd} ${x.m} - - - - "
        "L+ ${hd} - - - - ${root}/${hd}"
      ];
    in
    persistDirs ++ targetDirs ++ final;

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

      (mkIf config.programs.firefox.enable {
        ".cache/mozilla/firefox" = { };

        ${if config.aquaris.firefox.cleanHome
        then ".local/share/mozilla/firefox"
        else ".mozilla/firefox"} = { };
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

    systemd.user.tmpfiles.rules = pipe cfg [
      (filterAttrs (_: x: x.e))
      (mapAttrsToList mkEntry)
      builtins.concatLists
      unique
    ];
  };
}
