{ config, lib, mkEnableOption, osConfig, ... }:
let
  inherit (lib) concatStringsSep filter match mkIf pipe;

  cfg = config.aquaris.ssh;

  user = config.home.username;

  sshKeys = pipe osConfig.aquaris.secrets.all [
    (filter (x: match "user/${user}/ssh/[^/]+" x != null))
    (map osConfig.aquaris.secret)
  ];

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
      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          ForwardAgent = true;
          IdentityFile = sshKeys;
          UserKnownHostsFile = knownHosts;
        };

        github = {
          HostName = "github.com";
          User = "git";
        };
      };
    };

    services.ssh-agent.enable = true;

    systemd.user.tmpfiles.rules = pipe sshKeys [
      (map (x: "L+ '%h/.ssh/id_${baseNameOf x}' - - - - ${x}"))
      (x: x ++ [ "L+ '%h/.ssh/known_hosts' - - - - ${knownHosts}" ])
    ];
  };
}
