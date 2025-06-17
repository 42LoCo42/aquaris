{ pkgs, config, lib, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.starship;
in
{
  options.aquaris.starship = mkEnableOption "the starship shell prompt";

  config = mkIf cfg {
    programs.starship = {
      enable = true;
      settings = {
        character = {
          success_symbol = "[λ](bold green)";
          error_symbol = "[λ](bold red)";
        };

        custom.usepkgs = {
          when = ''[ -n "''${AQUARIS_USE+x}" ]'';
          command = pkgs.writeShellScript "usepkgs" ''
            readarray -t -d: path <<< "$PATH"
            for i in "''${path[@]}"; do
              awk '{
                if(match($0, /^\/nix\/store\/[^-]+-([^\/]+)/, a)) {
                  print a[1]
                } else {
                  exit 1
                }
              }' <<<"$i" || break
            done | paste -sd ' ' | sed 's|^|[m[1m|; s|$|[m|'
          '';
        };
      };
    };
  };
}
