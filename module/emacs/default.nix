{ pkgs, config, lib, ... }:
let
  inherit (lib) getExe makeBinPath mkEnableOption mkIf mkOption pipe;
  inherit (lib.types) listOf package pathInStore;

  cfg = config.aquaris.emacs;

  emacs = cfg.package;

  epkgs = ((pkgs.emacsPackagesFor emacs).overrideScope (_: prev: {
    straight = prev.trivialBuild rec {
      pname = "straight";
      version = "b3760f5";

      src = lib.sourceByRegex
        (pkgs.fetchFromGitHub {
          owner = "radian-software";
          repo = "straight.el";
          rev = version;
          hash = "sha256-KZUNGvR+UNx1ZpmkEVseSFFRTWUH5+smF84f+5+oe4I=";
        }) [ "straight.el" ];

      patches = [ ./straight.patch ];
    };
  })).overrideScope cfg.overrides;

  config-name = "default.el";

  config-source =
    if builtins.match ".*\.org" (toString cfg.config) != null
    then
      pkgs.runCommand config-name { } ''
        ${getExe emacs}        \
          -Q --batch           \
          --file ${cfg.config} \
          --eval "(org-babel-tangle-file buffer-file-name \"$out\")"
      ''
    else
      pipe cfg.config [
        builtins.readFile
        (pkgs.writeText config-name)
      ];

  emacs-config = epkgs.trivialBuild {
    pname = "config";
    version = "0";
    src = config-source;

    packageRequires = pipe config-source [
      (x: pkgs.runCommand "parse-emacs-config" { } ''
        set +o pipefail
        exec > $out
        echo 'p: with p; ['
        tr -d '()' < ${x}  \
        | grep use-package \
        | grep -v builtin  \
        | awk '{print $2}'
        echo ']'#
      '')
      (x: import x epkgs)
    ];
  };

  configured = epkgs.emacsWithPackages [ emacs-config ];

  final = pkgs.runCommandCC "emacs"
    { nativeBuildInputs = [ pkgs.makeBinaryWrapper ]; } ''
    makeWrapper ${getExe configured} $out/bin/emacs \
      --prefix PATH : ${makeBinPath cfg.extraPackages}
  '';
in
{
  options.aquaris.emacs = {
    enable = mkEnableOption "the declarative Emacs configuration";

    package = mkOption {
      description = "Emacs package to use";
      type = package;
      default = pkgs.emacs29;
    };

    extraPackages = mkOption {
      description = "Extra packages available to Emacs";
      type = listOf package;
      default = [ ];
    };

    config = mkOption {
      description = "Path to the config file";
      type = pathInStore;
    };

    overrides = mkOption {
      description = "Override function for emacsPackages";
      type = lib.types.anything;
      default = _: _: { };
    };
  };

  config = mkIf cfg.enable {
    home-manager.sharedModules = [{
      programs.emacs = {
        inherit (cfg) enable;
        package = final;
      };

      xdg.configFile."emacs/early-init.el".source = ./early-init.el;
    }];
  };
}
