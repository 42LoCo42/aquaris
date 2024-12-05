{ pkgs, config, lib, ... }:
let
  inherit (lib) getExe mkIf mkMerge mkOption pipe;
  inherit (lib.types) bool;

  cfg = config.aquaris.firefox;

  package = pipe pkgs.firefox [
    (x: if !cfg.cleanHome then x else
    x.overrideAttrs (old: {
      buildCommand = old.buildCommand + ''
        mv $out/bin/{firefox,.firefox-env}
        makeWrapper                                                        \
          ${getExe pkgs.boxxy}                                             \
          $out/bin/firefox                                                 \
          --add-flags --rule='~/.mozilla:~/.local/share/mozilla:directory' \
          --add-flags $out/bin/.firefox-env
      '';
    }))

    (x: x.override { cfg.speechSynthesisSupport = cfg.speechSynth; })
  ];
in
{
  options.aquaris.firefox = {
    enable = mkOption {
      description = "Enable Firefox";
      type = bool;
      default = false;
    };

    cleanHome = mkOption {
      description = "Move ~/.mozilla to ~/.local/share/mozilla";
      type = bool;
      default = false;
    };

    speechSynth = mkOption {
      description = "Enable speech synthesis support";
      type = bool;
      default = false;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      programs.firefox = {
        enable = true;
        inherit package;
      };
    }

    (mkIf cfg.cleanHome {
      assertions = [{
        assertion = false;
        message = "home-manager: aquaris.firefox.cleanHome is currently broken!";
      }];

      # TODO also move files of declarative firefox profiles
      home.file.".mozilla/native-messaging-hosts".target =
        ".local/share/mozilla/native-messaging-hosts";
    })
  ]);
}
