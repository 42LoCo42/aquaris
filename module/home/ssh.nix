{ lib, config, osConfig, mkEnableOption, ... }:
let
  inherit (lib)
    concatStringsSep
    filter
    hasPrefix
    mkIf
    mkMerge
    pipe
    ;

  cfg = config.aquaris.ssh;

  user = config.home.username;
  knownHosts = concatStringsSep "" [
    osConfig.aquaris.persist.root
    osConfig.users.users.${user}.home
    "/.cache/ssh-known-hosts"
  ];
in
{
  options.aquaris.ssh = mkEnableOption "SSH configuration";

  config = mkIf cfg {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks = {
        "*" = {
          addKeysToAgent = "yes";
          forwardAgent = true;
          userKnownHostsFile = knownHosts;

          identityFile = pipe osConfig.aquaris.secrets.all [
            (filter (hasPrefix "user/${user}/ssh/"))
            (map osConfig.aquaris.secret)
          ];
        };

        github = {
          hostname = "github.com";
          user = "git";
        };
      };
    };

    services.ssh-agent.enable = true;

    systemd.user.tmpfiles.rules = mkMerge [
      [ "L+ %h/.ssh/id_main     - - - - ${osConfig.aquaris.secret' "user/${user}/ssh/main"}" ]
      [ "L+ %h/.ssh/known_hosts - - - - ${knownHosts}" ]
    ];
  };
}
