{ config, lib, osConfig, ... }:
let
  inherit (lib) ifEnable mkOption pipe;
  inherit (lib.types) listOf str;

  cfg = config.aquaris.persist;

  inherit (osConfig.aquaris.persist) root;
  inherit (osConfig.users.users.${config.home.username}) home;

  allParents = file:
    if file == "/" || file == "." then [ ]
    else allParents (dirOf file) ++ [ file ];

  mkIn = pfx: map (x: "d ${pfx}/${x} 0755 - - - -");

  mkEntry = x:
    let
      persistDirs = pipe x [
        allParents
        (mkIn "${root}/${home}")
      ];

      targetDirs = pipe x [
        dirOf
        allParents
        (mkIn home)
      ];

      link = let hd = "${home}/${x}"; in [
        "L+ ${hd} - - - - ${root}/${hd}"
      ];
    in
    persistDirs ++ targetDirs ++ link;
in
{
  options.aquaris.persist = mkOption {
    description = "List of persistent directories";
    type = listOf str;
  };

  config = ifEnable osConfig.aquaris.persist.enable {
    aquaris.persist = [
      ".cache/nix"
    ] ++ ifEnable config.programs.firefox.enable [
      ".cache/mozilla/firefox"
      ".mozilla/firefox"
    ] ++ ifEnable config.programs.gpg.enable [
      ".gnupg"
    ] ++ ifEnable osConfig.services.sshd.enable [
      ".ssh"
    ] ++ ifEnable config.programs.zoxide.enable [
      ".local/share/zoxide"
    ] ++ ifEnable config.programs.zsh.enable [
      ".cache/zsh"
    ];

    systemd.user.tmpfiles.rules = builtins.concatMap mkEntry cfg;
  };
}
