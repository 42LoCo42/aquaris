{ pkgs, lib, config, my-utils, name, ... }:
let users = config.aquaris.users; in {
  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
  };
  environment.pathsToLink = [ "/share/zsh" ];

  users.users = builtins.mapAttrs (_: _: { shell = pkgs.zsh; }) users;

  home-manager.users = builtins.mapAttrs
    (_: _: { config, ... }: {
      home = {
        file = {
          ".profile".text = ''
            . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
          '';

          "bin/use" = {
            executable = true;
            source = ./misc/use.sh;
          };

          "bin/_usepkgs" = {
            executable = true;
            source = ./misc/usepkgs.sh;
          };

          "bin/switch" = {
            executable = true;
            text = my-utils.substituteAll ./misc/switch.sh {
              inherit name;
              nom = lib.getExe pkgs.nix-output-monitor;
              nvd = lib.getExe pkgs.nvd;
            };
          };
        };

        packages = with pkgs; [
          file
          git-crypt
          jq
          lsof
          man-pages
          man-pages-posix
          nil
          nix-output-monitor
          nixpkgs-fmt
          pciutils
          shellcheck
          tree
        ];

        sessionPath = [ "$HOME/bin" ];
        sessionVariables = {
          MANPAGER = "sh -c 'col -bx | bat -l man -p'";
          MANROFFOPT = "-c";
        };

        shellAliases = {
          cd = "z";
          ip = "ip -c";
          mkdir = "mkdir -pv";
          rmdir = "rmdir -pv";
          vi = "vi -p";
        };
      };

      programs = {
        bat = {
          enable = true;
          extraPackages = with pkgs.bat-extras; [ batman ];
          config = {
            theme = "gruvbox-dark";
            pager = "less -fR";
          };
        };

        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        fzf.enable = true;

        git = {
          enable = true;
          lfs.enable = true;
          delta = {
            enable = true;
            options = {
              side-by-side = true;
            };
          };
        };

        gpg.enable = true;

        htop = {
          enable = true;
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

        lsd = {
          enable = true;
          enableAliases = true;
          settings = {
            sorting.dir-grouping = "first";
          };
        };

        neovim = {
          enable = true;
          defaultEditor = true;
          viAlias = true;
          vimAlias = true;
          vimdiffAlias = true;

          extraConfig = builtins.readFile ./misc/init.vim;

          plugins = with pkgs.vimPlugins; [
            airline
            ale
            autoclose-nvim
            gitgutter
            vim-nix
            {
              plugin = deoplete-nvim;
              config = ''
                call deoplete#enable()
                call deoplete#custom#option("auto_complete_delay", 0)
              '';
            }
            { plugin = suda-vim; config = "let g:suda_smart_edit = 1"; }
          ];
        };

        ripgrep.enable = true;

        starship = {
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

        tmux = {
          enable = true;

          clock24 = true;
          escapeTime = 300;
          historyLimit = 10000;
          keyMode = "vi";
          mouse = true;
          shortcut = "w";
          terminal = "tmux-256color";

          extraConfig = builtins.readFile ./misc/tmux.conf;
        };

        zoxide.enable = true;

        zsh = let cache = "$HOME/.cache/zsh"; in {
          enable = true;
          enableAutosuggestions = true;
          syntaxHighlighting.enable = true;

          autocd = true;
          defaultKeymap = "emacs";
          history.path = "${cache}/history";

          initExtra = ''
            # bindkey "" insert-cycledright
            # bindkey "" insert-cycledleft

            bindkey "[1;3C" forward-word
            bindkey "[1;3D" backward-word

            # https://github.com/zsh-users/zsh-syntax-highlighting/issues/295#issuecomment-214581607
            zstyle ':bracketed-paste-magic' active-widgets '.self-*'
          '';

          plugins = [
            rec {
              name = "zsh-fzf-history-search";
              src = pkgs.fetchFromGitHub {
                owner = "joshskidmore";
                repo = name;
                rev = "d1aae98";
                hash = "sha256-4Dp2ehZLO83NhdBOKV0BhYFIvieaZPqiZZZtxsXWRaQ=";
              };
            }
          ];

          oh-my-zsh = {
            enable = true;
            extraConfig = ''ZSH_COMPDUMP="${cache}/completion"'';
            plugins = [
              "git-auto-fetch"
              "sudo"
            ];
          };
        };
      };
    })
    users;
}
