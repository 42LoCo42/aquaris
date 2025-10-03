# inspired by https://gitlab.com/rycee/nur-expressions/-/blob/master/hm-modules/emacs-init.nix
# https://gitlab.com/rycee/nur-expressions/-/blob/master/LICENSE

{ pkgs, config, lib, ... }:
let
  inherit (lib)
    filterAttrs
    flip
    isFunction
    mapAttrsToList
    mergeOneOption
    mkEnableOption
    mkIf
    mkOption
    mkOptionType
    pipe
    ;
  inherit (lib.types)
    attrsOf
    bool
    either
    functionTo
    int
    listOf
    package
    str
    submodule
    ;

  cfg = config.aquaris.emacs;

  ##########################################

  packageFunction = mkOptionType {
    name = "packageFunction";
    description = "function from epkgs to package";
    check = isFunction;
    merge = mergeOneOption;
  };

  code = mkOption {
    type = str;
    default = "";
  };

  toString' = x: if builtins.isBool x && x then "t" else toString x;
  ifEnable' = cond: text: if cond then text else "";

  usePackage = submodule ({ name, config, ... }: {
    options = {
      init = code;
      config = code;
      preface = code;

      mode = code;
      magic = code;
      magic-fallback = code;
      interpreter = code;

      commands = code;
      autoload = code;
      hook = code;

      bind = code;
      bind' = code;
      bind-keymap = code;
      bind-keymap' = code;

      defer = mkOption { type = either bool int; default = false; };
      demand = mkOption { type = bool; default = false; };

      after = code;

      ifexpr = code;
      defines = code;
      functions = code;
      load-path = code;
      diminish = code;
      delight = code;
      custom = code;
      custom-face = code;

      ##########################################

      package = mkOption {
        description = "Package name or function (taking epkgs)";
        type = either str packageFunction;
        default = name;
      };

      extraPackages = mkOption {
        description = "Extra packages to add to home.packages";
        type = listOf package;
        default = [ ];
      };

      _entry = mkOption {
        type = functionTo str;
        default = epkgs:
          let
            pname =
              if isFunction config.package
              then (config.package epkgs).pname
              else config.package;
          in
          pipe config [
            (flip builtins.removeAttrs [
              "_entry"
              "_module"
              "extraPackages"
              "package"
            ])
            (filterAttrs (_: flip pipe [
              (flip builtins.elem [ false "" ])
              (x: !x)
            ]))
            (mapAttrsToList (k: v: ''
              :${builtins.replaceStrings [ "'" ] ["*"] k}
              ${toString' v}
            ''))
            (builtins.concatStringsSep "")
            (x: ''
              (require '${pname}-autoloads "${pname}-autoloads" t)
              (use-package ${pname} ${x})
            '')
          ];
      };
    };
  });

  earlyInit = ''
    ;;; -*- lexical-binding: t -*-

    ${builtins.readFile ./gc-settings.el}
    (setq package-enable-at-startup nil)
    (setq frame-inhibit-implied-resize t)
    (provide 'hm-early-init)
  '';

  init = epkgs: pipe cfg.config [
    (mapAttrsToList (_: x: x._entry epkgs))
    (builtins.concatStringsSep "")
    (x: ''
      ;;; -*- lexical-binding: t -*-

      ${ifEnable' cfg.startupTimer ''
        (defun hm/print-startup-stats ()
          "Prints some basic startup statistics."
          (let ((elapsed (float-time (time-subtract after-init-time
                                                    before-init-time))))
            (message "Startup took %.2fs with %d GCs" elapsed gcs-done)))
        (add-hook 'emacs-startup-hook #'hm/print-startup-stats)
      ''}

      (eval-when-compile
        (require 'use-package)

        ${ifEnable' cfg.usePackage.alwaysDefer
          "(setq use-package-always-defer t)"}

        ${ifEnable' cfg.usePackage.statistics
          "(setq use-package-compute-statistics t)"}

        ${ifEnable' cfg.usePackage.verbose
          "(setq use-package-verbose t)"}
      )

      (require 'bind-key)
      ${ifEnable' cfg.usePackage.statistics
        "(require 'use-package-core)"}

      ${cfg.prelude}
      ${x}
      ${cfg.postlude}

      (provide 'hm-init)
    '')
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

    extraPackages = mkOption {
      description = "Extra packages available to Emacs";
      type = functionTo (listOf package);
      default = _: [ ];
    };

    startupTimer = mkOption {
      description = "Enable the startup timer";
      type = bool;
      default = true;
    };

    usePackage = {
      alwaysDefer = mkOption {
        description = "Always defer loading of packages";
        type = bool;
        default = false;
      };

      statistics = mkOption {
        description = "Gather statistics about package loading times";
        type = bool;
        default = false;
      };

      verbose = mkOption {
        description = "Log all loaded packages";
        type = bool;
        default = false;
      };
    };

    prelude = mkOption {
      description = "Config to add before loading packages";
      type = str;
      default = "";
    };

    postlude = mkOption {
      description = "Config to add after loading packages";
      type = str;
      default = "";
    };

    config = mkOption {
      description = "use-package entries";
      type = attrsOf usePackage;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    programs.emacs = {
      enable = true;
      package = cfg.package;

      extraPackages = epkgs:
        let
          getPkg = x:
            if isFunction x then (x epkgs)
            else (epkgs.${x} or null);

          packages = pipe cfg.config [
            builtins.attrValues
            (map (x: getPkg x.package))
            (builtins.filter (x: x != null))
            (x: x ++ cfg.extraPackages epkgs)
          ];
        in
        [
          (epkgs.trivialBuild {
            pname = "hm-early-init";
            version = "0.1.0";
            src = pkgs.writeText "hm-early-init.el" earlyInit;
            packageRequires = packages;
          })

          (epkgs.trivialBuild {
            pname = "hm-init";
            version = "0.1.0";
            src = pkgs.writeText "hm-init.el" (init epkgs);
            packageRequires = packages;
          })
        ];

      overrides = _: prev: {
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
    };

    home.packages = pipe cfg.config [
      (mapAttrsToList (_: x: x.extraPackages))
      builtins.concatLists
    ];

    xdg.configFile = {
      "emacs/early-init.el".text = ''
        (require 'hm-early-init)
      '';

      "emacs/init.el".text = ''
        (require 'hm-init)
      '';
    };
  };
}
