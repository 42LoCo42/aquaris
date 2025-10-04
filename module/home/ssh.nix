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
    programs.ssh = mkMerge [
      {
        enable = true;
        matchBlocks = {
          "*" = {
            forwardAgent = true;

            identityFile = pipe osConfig.aquaris.secrets.all [
              (filter (hasPrefix "user/${user}/ssh/"))
              (map osConfig.aquaris.secret)
            ];

            extraOptions = {
              AddKeysToAgent = "yes";
              UserKnownHostsFile = knownHosts;
            };
          };

          github = {
            hostname = "github.com";
            user = "git";
          };
        };
      }

      (if builtins.hasAttr "enableDefaultConfig" config.programs.ssh
      then { enableDefaultConfig = false; } else { })
    ];

    services.ssh-agent.enable = true;

    systemd.user.tmpfiles.rules = mkMerge [
      [ "L+ %h/.ssh/id_main     - - - - ${osConfig.aquaris.secret' "user/${user}/ssh/main"}" ]
      [ "L+ %h/.ssh/known_hosts - - - - ${knownHosts}" ]
    ];
  };
}
