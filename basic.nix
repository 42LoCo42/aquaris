{ inputs, config, lib, src, ... }:
let
  inherit (lib) mkForce mkOption types;
  inherit (types) path str;
  cfg = config.aquaris;
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  options.aquaris = {
    user = {
      name = mkOption {
        type = str;
        description = ''
          Name of the primary user account.
          This will be the entry `users.users.default`.
        '';
      };

      publicKey = mkOption {
        type = str;
        description = ''
          SSH public key of the user.
          Will be authorized for logins & used to select secrets.
        '';
      };

      secretKey = mkOption {
        type = path;
        description = ''
          Path to the SSH secret key of the user.
          Will be used for agenix to work with secret files.
        '';
        default = config.age.secrets."user/${cfg.user.name}/secretKey".path;
      };
    };

    system = {
      id = mkOption {
        type = str;
        description = ''
          Machine ID for systemd.
          The first 8 characters are used as hostId;
          Generate with `dbus-uuidgen`.
        '';
      };

      name = mkOption {
        type = str;
        description = ''
          Host name of the system.
          Should match the name of the NixOS configuration.
        '';
      };

      publicKey = mkOption {
        type = str;
        description = ''
          SSH ed25519 public key of the system.
          Will be used as host key & to select secrets.
        '';
      };

      secretKey = mkOption {
        type = path;
        description = ''
          Path to the SSH ed25519 secret key of the system.
          Will be used as host key & to decrypt secrets.
        '';
        default = config.age.secrets."system/${cfg.system.name}/secretKey".path;
      };

      keyMap = mkOption {
        type = str;
        description = "Key map of the system consoles (TTYs)";
        default = "de-latin1";
      };

      locale = mkOption {
        type = str;
        description = "The system locale";
        default = "en_US.UTF-8";
      };

      timeLocale = mkOption {
        type = str;
        description = "Locale setting for LC_TIME";
        default = "de_DE.UTF-8";
      };

      timeZone = mkOption {
        type = str;
        description = "Time zone of the system";
        default = "Europe/Berlin";
      };
    };
  };

  config = {
    system.stateVersion = "24.05";
    zramSwap.enable = true;

    boot = {
      loader = {
        timeout = 0;
        efi.canTouchEfiVariables = true;
        systemd-boot.editor = false;
      };

      # gruvbox
      kernelParams = [
        "vt.default_red=0x28,0xcc,0x98,0xd7,0x45,0xb1,0x68,0xa8,0x92,0xfb,0xb8,0xfa,0x83,0xd3,0x8e,0xeb"
        "vt.default_grn=0x28,0x24,0x97,0x99,0x85,0x62,0x9d,0x99,0x83,0x49,0xbb,0xbd,0xa5,0x86,0xc0,0xdb"
        "vt.default_blu=0x28,0x1d,0x1a,0x21,0x88,0x86,0x6a,0x84,0x74,0x34,0x26,0x2f,0x98,0x9b,0x7c,0xb2"
      ];

      initrd.systemd.enable = true; # is more modern and extensible
      tmp.useTmpfs = true; # /tmp is tmpfs
    };

    users.mutableUsers = false; # mutability is cringe
    users.users.default = {
      name = cfg.user.name;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPasswordFile = config.age.secrets."user/${cfg.user.name}/passwordHash".path;
      openssh.authorizedKeys.keys = [ cfg.user.publicKey ];
    };

    environment.etc."machine-id".text = cfg.system.id;
    networking.hostId = builtins.substring 0 8 cfg.system.id; # for ZFS
    networking.hostName = cfg.system.name;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
      hostKeys = [{
        path = cfg.system.secretKey;
        type = "ed25519";
      }];
    };

    console.keyMap = cfg.system.keyMap;
    i18n = {
      defaultLocale = cfg.system.locale;
      extraLocaleSettings.LC_TIME = cfg.system.timeLocale;
    };
    time.timeZone = cfg.system.timeZone;

    environment.etc."nixos".source = src; # link config source to /etc/nixos
    services.journald.extraConfig = "SystemMaxUse=500M"; # limit journal size
    systemd.extraConfig = "DefaultTimeoutStopSec=10s"; # fix systemd being annoying

    nix = {
      settings = {
        auto-optimise-store = true; # hardlink duplicate store files, massively decreases disk usage
        experimental-features = [ "nix-command" "flakes" ]; # enable flakes
        substituters = [
          "https://nix-community.cachix.org"
          "https://42loco42.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "42loco42.cachix.org-1:6HvWFER3RdTSqEZDznqahkqaoI6QCOiX2gRpMMsThiQ="
        ];
      };

      nixPath = mkForce [ "nixpkgs=/etc/nix/channel" ];
      # TODO link nixpkgs to system registry
    };

    environment.etc."nix/channel".source = inputs.nixpkgs.outPath;
  };
}
