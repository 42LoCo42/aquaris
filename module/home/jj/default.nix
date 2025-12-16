{ pkgs, lib, config, mkEnableOption, ... }:
let
  inherit (lib)
    getExe
    mkAfter
    mkIf
    mkMerge
    pipe
    ;

  cfg = config.aquaris.jj;
  inherit (config.programs) git;
in
{
  options.aquaris.jj = mkEnableOption "jujutsu, a simple git-compatible VCS";

  config = mkIf cfg {
    programs.jujutsu = {
      enable = true;
      settings = mkMerge [
        {
          ui = {
            always-allow-large-revsets = true;

            diff-formatter = [
              (getExe pkgs.difftastic)
              "--color=always"
              "$left"
              "$right"
            ];
          };
        }

        (mkIf (builtins.hasAttr "name" git.settings.user) { user.name = git.settings.user.name; })
        (mkIf (builtins.hasAttr "email" git.settings.user) { user.email = git.settings.user.email; })

        ((mkIf (builtins.all (x: x) [
          (git.signing != null)
          (git.signing.key != null)
          (git.signing.format == "ssh")
        ])) {
          signing = {
            backend = "ssh";
            behavior = "own";
            inherit (git.signing) key;
          };
        })
      ];
    };

    programs.zsh.oh-my-zsh.extraConfig = pipe ./functions.sh [
      builtins.readFile
      mkAfter
    ];

    home = {
      sessionVariables.LESS = "-i -R";

      shellAliases = {
        j = "jj";
        ja = "jj abandon";
        jbd = "jj bookmark delete";
        jbl = "jj bookmark list --no-pager";
        jbla = "jj bookmark list --all --no-pager";
        jbs = "jj bookmark set";
        jbt = "jj bookmark track";
        jc = "jj git clone --colocate";
        jd = "jj describe -m";
        jde = "jj describe --edit";
        jdg = "jj diff --git";
        jdi = "jj diff";
        jdu = "jj duplicate";
        je = "jj edit";
        jfa = "jj file annotate";
        jfl = "jj file list";
        jfs = "jj file show";
        jfu = "jj file untrack";
        ji = "jj git init --colocate";
        jl = "jj log -r ::";
        jn = "jj new";
        jol = "jj op log";
        jor = "jj op restore";
        jos = "jj op show";
        jou = "jj op undo";
        jpa = "jj parallelize";
        jpl = "jj git fetch --all-remotes"; # "pull"
        jpu = "jj git push --all --deleted"; # jps is intelligent push
        jr = "jj rebase";
        jra = "jj git remote add";
        jrd = "jj git remote remove"; # "delete"
        jre = "jj restore";
        jrei = "jj restore -i";
        jrl = "jj git remote list --no-pager";
        jrr = "jj git remote rename";
        jrs = "jj git remote set-url";
        js = "jj show";
        jsc = "jj show $(jfc)";
        jsg = "jj show --git";
        jsp = "jj split";
        jsq = "jj squash";
        jsqi = "jj squash -i";
        jss = "jj show --stat";
        jtd = "jj tag delete";
        jtl = "jj tag list --no-pager";
        jts = "jj tag set --allow-move";
        ju = "jj undo";
      };
    };
  };
}
