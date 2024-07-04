{
  home.shellAliases.neofetch = "hyfetch";

  programs = {
    fastfetch.enable = true;

    hyfetch = {
      enable = true;
      settings = {
        backend = "fastfetch";

        mode = "rgb";
        light_dark = "dark";
        lightness = 0.5;

        preset = "transgender";
        color_align = {
          mode = "custom";
          custom_colors = {
            "1" = 1;
            "2" = 0;
          };
        };
      };
    };
  };
}
