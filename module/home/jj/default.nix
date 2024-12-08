{ lib, config, mkEnableOption, ... }:
let
  inherit (lib)
    mkAfter
    mkIf
    mkMerge
    pipe
    ;

  cfg = config.aquaris.jj;
  git = config.programs.git;
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
          (git.extraConfig.gpg.format == "ssh")
        ])) {
          signing = {
            backend = "ssh";
            key = git.signing.key;
            sign-all = true;
          };
        })
      ];
    };

    programs.zsh.oh-my-zsh.extraConfig = pipe ./functions.sh [
      builtins.readFile
      mkAfter
    ];

    home = {
      sessionVariables.LESS = "-i -F -R";

      shellAliases = {
        j = "jj";
        ja = "jj abandon";
        jbd = "jj bookmark delete";
        jbl = "jj bookmark list";
        jbla = "jj bookmark list --all";
        jbs = "jj bookmark set";
        jbt = "jj bookmark track";
        jc = "jj git clone --colocate";
        jd = "jj describe -m";
        jdi = "jj diff";
        je = "jj edit";
        jfs = "jj file show";
        ji = "jj git init --colocate";
        jl = "jj log";
        jla = "jj log -r ::";
        jlr = "jj log --reversed";
        jn = "jj new";
        jnm = "jj new -m";
        jol = "jj op log";
        jor = "jj op restore";
        jos = "jj op show";
        jou = "jj op undo";
        jpl = "jj git fetch"; # "pull"
        jpu = "jj git push"; # jps is intelligent push
        jr = "jj rebase";
        jra = "jj git remote add";
        jrd = "jj git remote remove"; # "delete"
        jre = "jj restore";
        jrl = "jj git remote list";
        jrs = "jj git remote set-url";
        js = "jj show";
        jsp = "jj split";
        jspi = "jj split -i";
        jsq = "jj squash";
        jsqi = "jj squash -i";
        ju = "jj file untrack";
        jun = "jj undo";
      };
    };
  };
}
