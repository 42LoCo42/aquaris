{ lib, config, mkEnableOption, ... }:
let
  inherit (lib)
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
        (mkIf (git.userName != null) { user.name = git.userName; })
        (mkIf (git.userEmail != null) { user.email = git.userEmail; })

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
        je = "jj edit";
        ji = "jj git init --colocate";
        jl = "jj log -r ::";
        jn = "jj new";
        jol = "jj op log";
        jor = "jj op restore";
        jos = "jj op show";
        jou = "jj op undo";
        jpl = "jj git fetch"; # "pull"
        jpu = "jj git push --all"; # jps is intelligent push
        jr = "jj rebase";
        jra = "jj git remote add";
        jrd = "jj git remote remove"; # "delete"
        jre = "jj restore";
        jrl = "jj git remote list --no-pager";
        jrs = "jj git remote set-url";
        js = "jj show";
        jsp = "jj split";
        jsq = "jj squash";
        jsqi = "jj squash -i";
        jut = "jj file untrack";
        jun = "jj undo";
      };
    };
  };
}
