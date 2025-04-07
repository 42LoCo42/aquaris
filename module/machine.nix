{ self, aquaris, lib, config, pkgs, ... }:
let
  inherit (lib) getExe mkDefault mkIf mkOption;
  inherit (lib.types) bool int lines nullOr str;
  inherit (aquaris.inputs) nixpkgs;
  cfg = config.aquaris.machine;

  # pin exactly this version since it's cached in nix-community.cachix.org
  lanza042 = builtins.getFlake "github:nix-community/lanzaboote/a65905a09e2c43ff63be8c0e86a93712361f871e";

  inherit (config.aquaris.persist) root;
in
{
  options = {
    aquaris.machine = {
      id = mkOption {
        description = "The machine ID (used by systemd and others)";
        type = str;
      };

      secureboot = mkOption {
        description = "Whether to enable Secure Boot support using lanzaboote";
        type = bool;
        default = true;
      };

      keepGenerations = mkOption {
        description = "How many generations to keep (null to disable autocleanup)";
        type = nullOr int;
        default = 5;
      };
    };

    boot.lanzaboote = {
      createKeys = mkOption {
        description = "Automatically create secure boot keys";
        type = bool;
        default = true;
      };

      preCommands = mkOption {
        description = "Commands to run before lanzaboote entries are installed";
        type = lines;
        default = "";
      };

      postCommands = mkOption {
        description = "Commands to run after lanzaboote entries have been installed";
        type = lines;
        default = "";
      };
    };
  };

  imports = [ "${lanza042}/nix/modules/lanzaboote.nix" ];

  config = {
    boot = {
      initrd.systemd.enable = mkDefault true;

      kernelParams = [
        "vt.default_red=0x28,0xcc,0x98,0xd7,0x45,0xb1,0x68,0xa8,0x92,0xfb,0xb8,0xfa,0x83,0xd3,0x8e,0xeb"
        "vt.default_grn=0x28,0x24,0x97,0x99,0x85,0x62,0x9d,0x99,0x83,0x49,0xbb,0xbd,0xa5,0x86,0xc0,0xdb"
        "vt.default_blu=0x28,0x1d,0x1a,0x21,0x88,0x86,0x6a,0x84,0x74,0x34,0x26,0x2f,0x98,0x9b,0x7c,0xb2"
      ];

      lanzaboote = {
        enable = mkDefault cfg.secureboot;
        configurationLimit = cfg.keepGenerations;
        pkiBundle = mkDefault "/var/lib/sbctl";

        preCommands =
          let pki = config.boot.lanzaboote.pkiBundle; in
          mkIf config.boot.lanzaboote.createKeys ''
            if [ ! -f "${pki}/GUID" ]; then
              ${getExe pkgs.sbctl} create-keys
            fi
          '';

        package = pkgs.writeShellApplication {
          name = "lzbt";
          text = ''
            ${config.boot.lanzaboote.preCommands}
            ${getExe lanza042.packages.${pkgs.system}.lzbt} "$@"
            ${config.boot.lanzaboote.postCommands}
          '';
        };
      };

      loader = {
        efi.canTouchEfiVariables = mkDefault true;
        timeout = mkDefault 0;

        systemd-boot = {
          enable = mkDefault (! cfg.secureboot);
          configurationLimit = cfg.keepGenerations;
          editor = mkDefault false;
        };
      };

      tmp.useTmpfs = mkDefault true;
    };

    environment.etc = {
      "machine-id".text = cfg.id;
      "nix/channel".source = nixpkgs.outPath;
      "nixos".source = self.outPath;
    };

    networking = {
      hostId = builtins.substring 0 8 cfg.id; # for ZFS
      hostName = aquaris.name;
      useNetworkd = mkDefault true;

      networkmanager = {
        enable = mkDefault true;
        plugins = lib.mkOverride 99 [ ];
      };
    };

    nix = {
      package = mkDefault pkgs.lix;

      settings = {
        auto-optimise-store = true;
        experimental-features = [ "nix-command" "flakes" ];
        keep-going = true;
        use-xdg-base-directories = true;
      };

      nixPath = [ "nixpkgs=/etc/nix/channel" ];

      registry = {
        config.flake = self;

        nixpkgs.to = {
          type = "github";
          owner = "nixos";
          repo = "nixpkgs";
          inherit (nixpkgs) rev;
        };
      };
    };

    services = {
      journald.extraConfig = mkDefault "SystemMaxUse=100M";

      openssh = {
        enable = mkDefault true;

        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };

        hostKeys = [{
          path = "${root}/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }];
      };
    };

    system = {
      configurationRevision = mkDefault (self.rev or self.dirtyRev or null);
      etc.overlay.enable = mkDefault true;
      stateVersion = mkDefault "24.05";
    };

    # misc
    console.keyMap = mkDefault "de-latin1";
    i18n.extraLocaleSettings.LC_COLLATE = mkDefault "C.UTF-8";
    i18n.extraLocaleSettings.LC_TIME = mkDefault "de_DE.UTF-8";
    systemd.extraConfig = mkDefault "DefaultTimeoutStopSec=5s";
    time.timeZone = mkDefault "Europe/Berlin";
    zramSwap.enable = mkDefault true;
  };
}
