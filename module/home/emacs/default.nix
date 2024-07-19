{ pkgs, config, lib, ... }:
let
  inherit (lib) getExe mkEnableOption mkIf mkOption pipe;
  inherit (lib.types) listOf package pathInStore;

  cfg = config.aquaris.emacs;

  ##########################################

  extraOverrides = _: prev: {
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
  };

  ##########################################

  fileExtIs = ext: file: builtins.match ".*\.${ext}" (toString file) != null;

  mkConfig = file: pipe file [
    builtins.readFile
    (x: ''
      ;;; -*- lexical-binding: t -*-
      (setenv "PATH" (format "%s:%s" (car exec-path) (getenv "PATH")))
    '' + x)
  ];

  extraConfig =
    if fileExtIs "el" cfg.config then mkConfig cfg.config else
    if fileExtIs "org" cfg.config then
      pipe cfg.config [
        (x: pkgs.runCommand "emacs-tangle-config" { } ''
          ${getExe cfg.package} -Q --batch --file ${x} \
            --eval "(org-babel-tangle-file buffer-file-name \"$out\")"
        '')
        mkConfig
      ]
    else abort "Emacs config file ${cfg.config} has invalid type!";

  ##########################################

  extraPackages = epkgs: pipe extraConfig [
    (pkgs.writeText "emacs-config")
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
    (x: x ++ cfg.extraPrograms)
  ];
in
{
  options.aquaris.emacs = {
    enable = mkEnableOption "the declarative Emacs configuration";

    package = mkOption {
      description = "Emacs package to use";
      type = package;
      default = pkgs.emacs29;
    };

    extraPrograms = mkOption {
      description = "Extra programs available to Emacs";
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
    programs.emacs = {
      inherit (cfg) enable package;
      inherit extraConfig extraPackages;

      overrides = final: prev:
        cfg.overrides final prev //
        extraOverrides final prev;
    };

    xdg.configFile."emacs/early-init.el".source = ./early-init.el;
  };
}
