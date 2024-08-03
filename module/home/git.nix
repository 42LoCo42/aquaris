{ pkgs, lib, config, osConfig, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.git;
  user = osConfig.aquaris.users.${config.home.username}.git;
in
{
  options.aquaris.git = mkEnableOption "Git with helpful aliases and features";

  config = mkIf cfg {
    home = {
      packages = with pkgs; [
        git-crypt
      ];

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
        lfs.enable = true;

        delta = {
          enable = true;
          options = {
            paging = "always";
            side-by-side = true;
          };
        };

        userName = user.name;
        userEmail = user.email;

        signing = {
          key = user.key;
          signByDefault = config.programs.git.signing.key != null;
        };

        extraConfig = {
          pull.rebase = false;
          push.autoSetupRemote = true;
        };
      };

      gpg.enable = true;
    };
  };
}
