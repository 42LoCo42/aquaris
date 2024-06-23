{ self, aquaris, nixpkgs, lib, config, pkgs, ... }:
let
  inherit (lib) mkDefault mkForce mkIf mkOption;
  inherit (lib.types) bool str;
  cfg = config.aquaris.machine;

  # pin exactly this version since it's cached in nix-community.cachix.org
  lanza041 = builtins.getFlake "github:nix-community/lanzaboote/b627ccd97d0159214cee5c7db1412b75e4be6086?narHash=sha256-eSZyrQ9uoPB9iPQ8Y5H7gAmAgAvCw3InStmU3oEjqsE%3D";
in
{
  options.aquaris.machine = {
    id = mkOption {
      description = "The machine ID (used by systemd and others)";
      type = str;
    };

    enableSSH = mkOption {
      description = "Whether to enable the OpenSSH server";
      type = bool;
      default = true;
    };

    secureboot = mkOption {
      description = "Whether to enable Secure Boot support using lanzaboote";
      type = bool;
      default = true;
    };
  };

  imports = [ lanza041.nixosModules.lanzaboote ];

  config = {
    system = {
      extraDependencies = [ nixpkgs ];
      stateVersion = "24.05";
    };

    boot = {
      initrd.systemd.enable = mkDefault true;

      kernelParams = [
        "vt.default_red=0x28,0xcc,0x98,0xd7,0x45,0xb1,0x68,0xa8,0x92,0xfb,0xb8,0xfa,0x83,0xd3,0x8e,0xeb"
        "vt.default_grn=0x28,0x24,0x97,0x99,0x85,0x62,0x9d,0x99,0x83,0x49,0xbb,0xbd,0xa5,0x86,0xc0,0xdb"
        "vt.default_blu=0x28,0x1d,0x1a,0x21,0x88,0x86,0x6a,0x84,0x74,0x34,0x26,0x2f,0x98,0x9b,0x7c,0xb2"
      ];

      lanzaboote = {
        enable = mkDefault cfg.secureboot;
        pkiBundle = "/etc/secureboot";
        package = mkForce (pkgs.writeShellScriptBin "lzbt" ''
          [ -e /etc/secureboot/keys ] || ${pkgs.sbctl}/bin/sbctl create-keys
          exec ${lanza041.packages.${pkgs.system}.tool}/bin/lzbt "$@"
        '');
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
      "nixos".source = self;
    };

    networking = {
      networkmanager.enable = mkDefault true;
      hostId = builtins.substring 0 8 cfg.id; # for ZFS
      hostName = aquaris.name;
      useNetworkd = mkDefault true;
    };

    nix = {
      package = pkgs.nixVersions.latest;

      settings = {
        auto-optimise-store = true;
        experimental-features = [ "nix-command" "flakes" ];
      };

      registry.nixpkgs.to = {
        type = "github";
        owner = "nixos";
        repo = "nixpkgs";
        inherit (nixpkgs) rev;
      };
    };

    services = {
      journald.extraConfig = mkDefault "SystemMaxUse=100M";

      openssh = mkIf cfg.enableSSH {
        enable = true;

        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };

        # TODO
        # hostKeys = [{
        #   path = cfg.machine.secretKey;
        #   type = "ed25519";
        # }];
      };
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
