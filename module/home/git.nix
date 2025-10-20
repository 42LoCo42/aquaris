{ pkgs, lib, config, osConfig, mkEnableOption, ... }:
let
  inherit (lib)
    findFirst
    mapNullable
    mkDefault
    mkIf
    mkMerge
    mkOption
    pipe
    splitString
    ;

  inherit (lib.types)
    coercedTo
    functionTo
    nullOr
    str
    ;

  cfg = config.aquaris.git;
  user = osConfig.aquaris.users.${config.home.username}.git;
in
{
  options.aquaris.git = {
    enable = mkEnableOption "Git with helpful aliases and features";

    sshKeyFile = mkOption {
      type = coercedTo
        (functionTo str)
        (f:
          if user.key == null then null else
          pipe user.key [
            (splitString " ")
            builtins.head
            (type: findFirst (x: x.type == type) null [
              { type = "ecdsa-sha2-nistp256"; name = "ecdsa"; }
              { type = "sk-ecdsa-sha2-nistp256@openssh.com"; name = "ecdsa_sk"; }
              { type = "sk-ssh-ed25519@openssh.com"; name = "ed25519_sk"; }
              { type = "ssh-ed25519"; name = "ed25519"; }
              { type = "ssh-rsa"; name = "rsa"; }
            ])
            (mapNullable f)
          ])
        (nullOr str);
      description = ''
        Function to locate the SSH private key.

        { name (string): Default file name of the SSH key (id_<name>)
        , type (string): Type prefix of the passed public key
        } -> string: Path to the SSH private key
      '';
      default = x: "~/.ssh/id_${x.name}";
    };
  };

  config = mkIf cfg.enable {
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

    programs = {
      git = {
        enable = true;
        lfs.enable = mkDefault true;

        signing = mkIf (user.key != null) {
          format = if cfg.sshKeyFile != null then "ssh" else "openpgp";
          key = mkDefault (if cfg.sshKeyFile != null then cfg.sshKeyFile else user.key);
          signByDefault = mkDefault true;
        };

        settings = mkMerge [
          {
            merge.tool = mkDefault "vimdiff";
            pull.rebase = mkDefault false;
            push.autoSetupRemote = mkDefault true;
            user.name = mkDefault user.name;
          }

          (mkIf (user.email != null) {
            user.email = mkDefault user.email;
          })

          (mkIf (user.email != null && user.key != null && cfg.sshKeyFile != null) {
            gpg.ssh.allowedSignersFile = mkDefault (
              pkgs.writeText "allowedSigners" ''
                ${user.email} namespaces="git" ${user.key}
              ''
            ).outPath;
          })
        ];
      };

      delta = {
        enable = mkDefault true;
        options = {
          paging = mkDefault "always";
          side-by-side = mkDefault true;
        };
      };
    };
  };
}
