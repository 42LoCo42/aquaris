{ mkEnableOption, ... }: {
  options.aquaris.starship = mkEnableOption "the starship shell prompt";

  config = {
    programs.starship = {
      enable = true;
      settings = {
        custom.usepkgs = {
          command = "_usepkgs";
          when = ''[ -n "$IN_USE_SHELL" ]'';
        };
        character = {
          success_symbol = "[λ](bold green)";
          error_symbol = "[λ](bold red)";
        };
      };
    };
  };
}
