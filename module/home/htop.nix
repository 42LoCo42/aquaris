{ pkgs, config, lib, obscura, mkEnableOption, ... }:
let
  inherit (lib) mkIf;
  cfg = config.aquaris.htop;
in
{
  options.aquaris.htop = mkEnableOption "preconfigured htop";

  config = mkIf cfg {
    home.activation.fix-htop = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      rm -f -v "$HOME/.config/htop/htoprc"
    '';

    programs.htop = {
      enable = true;
      package = obscura.packages.${pkgs.system}.my-htop;

      settings = {
        account_guest_in_cpu_meter = 1;
        color_scheme = 5;
        hide_userland_threads = 1;
        highlight_base_name = 1;
        highlight_changes = 1;
        highlight_changes_delay_secs = 1;
        show_cpu_frequency = 1;
        show_cpu_temperature = 1;
        show_merged_command = 1;
        show_program_path = 0;
        show_thread_names = 1;
        tree_view = 1;

        tree_sort_key = config.lib.htop.fields.COMM;
        tree_sort_direction = 1;

        fields = with config.lib.htop.fields; [
          PID
          USER
          STATE
          NICE
          PERCENT_CPU
          PERCENT_MEM
          M_RESIDENT
          OOM
          TIME
          COMM
        ];
      } // (with config.lib.htop; leftMeters [
        (bar "AllCPUs")
        (bar "Memory")
        (bar "Zram")
        (bar "DiskIO")
        (bar "NetworkIO")
        (bar "Load")
        (text "Clock")
      ]) // (with config.lib.htop; rightMeters [
        (text "AllCPUs")
        (text "Memory")
        (text "Zram")
        (text "DiskIO")
        (text "NetworkIO")
        (text "LoadAverage")
        (text "Uptime")
      ]);
    };
  };
}
