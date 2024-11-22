{ config, lib, osConfig, ... }:
let
  inherit (lib) ifEnable mkOption pipe;
  inherit (lib.types) coercedTo listOf str submodule;

  cfg = config.aquaris.persist;

  inherit (osConfig.aquaris.persist) root;
  inherit (osConfig.users.users.${config.home.username}) home;

  allParents = file:
    if file == "/" || file == "." then [ ]
    else allParents (dirOf file) ++ [ file ];

  mkIn = pfx: map (x: "d ${pfx}/${x} 0755 - - - -");

  mkEntry = x:
    let
      persistDirs = pipe x.d [
        allParents
        (mkIn "${root}/${home}")
      ];

      targetDirs = pipe x.d [
        dirOf
        allParents
        (mkIn home)
      ];

      final = let hd = "${home}/${x.d}"; in [
        "z ${root}/${hd} ${x.m} - - - - "
        "L+ ${hd} - - - - ${root}/${hd}"
      ];
    in
    persistDirs ++ targetDirs ++ final;

  entry = submodule {
    options = {
      d = mkOption {
        description = "Directory";
        type = str;
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
    type = listOf (coercedTo str (d: { inherit d; }) entry);
  };

  config = ifEnable osConfig.aquaris.persist.enable {
    aquaris.persist = [
      ".cache/nix"
    ] ++ ifEnable config.programs.firefox.enable [
      ".cache/mozilla/firefox"
      (if config.aquaris.firefox.cleanHome
      then ".local/share/mozilla/firefox"
      else ".mozilla/firefox")
    ] ++ ifEnable config.programs.gpg.enable [
      { d = ".gnupg"; m = "0700"; }
    ] ++ ifEnable osConfig.services.sshd.enable [
      { d = ".ssh"; m = "0700"; }
    ] ++ ifEnable config.programs.zoxide.enable [
      ".local/share/zoxide"
    ] ++ ifEnable config.programs.zsh.enable [
      ".cache/zsh"
    ];

    systemd.user.tmpfiles.rules = builtins.concatMap mkEntry cfg;
  };
}
