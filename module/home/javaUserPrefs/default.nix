{ pkgs, config, lib, ... }:
let
  inherit (lib) getExe mkOption;
  inherit (lib.strings) toJSON;
  inherit (lib.types) attrsOf lines;
  cfg = config.programs.java.userPrefs;
in
{
  options = {
    programs.java.userPrefs = mkOption {
      type = attrsOf lines;
      default = { };
    };
  };

  config = {
    assertions = [
      (lib.hm.assertions.assertPlatform "systemd.user.tmpfiles" pkgs lib.platforms.linux)
    ];

    xdg.configFile."user-tmpfiles.d/javaUserPrefs.conf" = {
      source = (pkgs.runCommand "javaUserPrefs" { } ''
        mkdir -p $out/files; cd $out
        ${getExe pkgs.python3} ${./gen.py} <<\EOF
        ${toJSON cfg}
        EOF
      '') + /conf;

      onChange = ''
        run ${pkgs.systemd}/bin/systemd-tmpfiles --user --remove --create ''${DRY_RUN:+--dry-run}
      '';
    };
  };
}
