{ pkgs, lib, config, osConfig, mkEnableOption, ... }:
let
  inherit (lib)
    findFirst
    mapNullable
    mkDefault
    mkIf
    mkMerge
    pipe
    splitString
    ;

  cfg = config.aquaris.git;
  user = osConfig.aquaris.users.${config.home.username}.git;

  ##### ssh key stuff #####

  allowedSigners = pkgs.writeText "allowedSigners" ''
    ${user.email} namespaces="git" ${user.key}
  '';

  sshKeyFile = pipe user.key [
    (splitString " ")
    builtins.head
    (type: findFirst (x: x.type == type) null [
      { type = "ecdsa-sha2-nistp256"; name = "ecdsa"; }
      { type = "sk-ecdsa-sha2-nistp256@openssh.com"; name = "ecdsa_sk"; }
      { type = "sk-ssh-ed25519@openssh.com"; name = "ed25519_sk"; }
      { type = "ssh-ed25519"; name = "ed25519"; }
      { type = "ssh-rsa"; name = "rsa"; }
    ])
    (mapNullable (x: "~/.ssh/id_${x.name}"))
  ];
in
{
  options.aquaris.git = mkEnableOption "Git with helpful aliases and features";

  config = mkIf cfg {
    home = {
      packages = with pkgs; [ git-crypt ];

      shellAliases = {
        g = "git";

        ga = "git add";
        gan = "git add --intent-to-add";
        gap = "git add --patch";

        gc = "git commit";
        gcm = "git commit --message";
        gcam = "git commit --all --message";

        gd = "git diff";
        gds = "git diff --staged";

        gl = "git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %aN%C(reset)%C(bold yellow)%d%C(reset)' --all";

        gpl = "git pull";

        gps = "git push";
        gpsf = "git push --force-with-lease --force-if-includes";

        gr = "git restore";
        grs = "git restore --staged";

        gs = "git show";
      };
    };

    programs.git = {
      enable = true;
      lfs.enable = mkDefault true;

      delta = {
        enable = mkDefault true;
        options = {
          paging = mkDefault "always";
          side-by-side = mkDefault true;
        };
      };

      userName = mkDefault user.name;
      userEmail = mkDefault user.email;

      signing = mkIf (user.key != null) {
        key = mkDefault (if sshKeyFile != null then sshKeyFile else user.key);
        signByDefault = mkDefault true;
      };

      extraConfig = mkMerge [
        {
          merge.tool = mkDefault "vimdiff";
          pull.rebase = mkDefault false;
          push.autoSetupRemote = mkDefault true;
        }

        (mkIf (user.key != null) {
          gpg.format = if sshKeyFile != null then "ssh" else "openpgp";
        })

        (mkIf (user.key != null && sshKeyFile != null) {
          gpg.ssh.allowedSignersFile = mkDefault allowedSigners.outPath;
        })
      ];
    };
  };
}
