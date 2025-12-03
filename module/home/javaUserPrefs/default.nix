{ pkgs, config, lib, ... }:
let
  inherit (lib) getExe isFunction mapAttrs mkIf mkOption pipe;
  inherit (lib.strings) toJSON;
  inherit (lib.types) attrsOf either functionTo lines;
  inherit (pkgs.formats) xml;

  cfg = config.programs.java.userPrefs;

  python = pkgs.python3.withPackages (p: with p; [
    yq
  ]);
in
{
  options = {
    programs.java.userPrefs = mkOption {
      type = attrsOf (either (xml { }).type (functionTo lines));
      default = { };
    };
  };

  config = mkIf (cfg != { }) {
    assertions = [
      (lib.hm.assertions.assertPlatform "systemd.user.tmpfiles" pkgs lib.platforms.linux)
    ];

    xdg.configFile."user-tmpfiles.d/javaUserPrefs.conf" = {
      source = pipe cfg [
        (mapAttrs (_: x: rec {
          raw = isFunction x;
          val = if raw then x null else toJSON x;
        }))
        (x: (pkgs.runCommand "javaUserPrefs" { } ''
          mkdir -p $out/files; cd $out
          ${getExe python} ${./gen.py} <<\EOF
          ${toJSON x}
          EOF
        '') + /conf)
      ];

      onChange = ''
        run ${pkgs.systemd}/bin/systemd-tmpfiles --user --remove --create ''${DRY_RUN:+--dry-run}
      '';
    };
  };
}
