{ self, aquaris, lib, config, pkgs, ... }:
let
  inherit (lib) ifEnable mkDefault mkOption pipe;
  inherit (lib.types) bool int nullOr str;
  inherit (aquaris.inputs) nixpkgs;
  cfg = config.aquaris.machine;

  # pin exactly this version since it's cached in nix-community.cachix.org
  lanza042 = builtins.getFlake "github:nix-community/lanzaboote/a65905a09e2c43ff63be8c0e86a93712361f871e";

  inherit (config.aquaris.persist) root;
in
{
  options.aquaris.machine = {
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

        pkiBundle = pipe pkgs.sbctl.ldflags [
          (builtins.concatStringsSep " ")
          (builtins.match ".*DatabasePath=([^ ]+).*")
          builtins.head
        ];

        package = pkgs.writeShellApplication {
          name = "lzbt";

          runtimeInputs = with pkgs; [
            lanza042.packages.${pkgs.system}.lzbt
            sbctl
          ];

          text = let pki = config.boot.lanzaboote.pkiBundle; in ''
            if [ ! -f "${pki}/GUID" ]; then
              sbctl create-keys
            fi
            exec lzbt "$@"
          '';
        };
      };

      loader = {
        efi.canTouchEfiVariables = mkDefault true;
        timeout = mkDefault 0;

        systemd-boot = {
          enable = mkDefault (! cfg.secureboot);
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
      activationScripts = ifEnable (cfg.keepGenerations != null) {
        keepGenerations = ''
          ${config.nix.package}/bin/nix-env --profile /nix/var/nix/profiles/system \
            --delete-generations "+${toString cfg.keepGenerations}"
        '';
      };

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
