{ config, lib, src, self, ... }:
let
  inherit (lib) mkForce mkOption pipe types;
  inherit (types) attrsOf bool nullOr path str submodule;
  cfg = config.aquaris;
  persist = cfg.persist.root;
in
{
  options.aquaris = {
    users = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          name = mkOption {
            type = nullOr str;
            description = "Real username, overrides attrset name.";
            default = name;
          };

          isAdmin = mkOption {
            type = bool;
            description = "Should this user be added to the wheel group?";
            default = false;
          };

          publicKey = mkOption {
            type = str;
            description = ''
              SSH public key of the user.
              Will be authorized for logins.
            '';
          };
        };
      }));
      default = { };
    };

    machine = {
      # these options will be inherited from ${src}/default.nix

      name = mkOption {
        type = str;
        description = ''
          Host name of the machine.
          Should match the name of the NixOS configuration.
        '';
      };

      id = mkOption {
        type = str;
        description = ''
          Machine ID for systemd.
          The first 8 characters are used as hostId;
          Generate with `dbus-uuidgen`.
        '';
      };

      publicKey = mkOption {
        type = str;
        description = ''
          SSH ed25519 public key of the machine.
          Will be used as host key & to select secrets.
        '';
      };

      # inheritance end

      secretKey = mkOption {
        type = path;
        description = ''
          Path to the SSH ed25519 secret key of the machine.
          Will be used as host key & to decrypt secrets.
        '';
        default = "${persist}/etc/ssh/ssh_host_ed25519_key";
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
        description = "Time zone of the machine";
        default = "Europe/Berlin";
      };
    };
  };

  imports = [ self.inputs.home-manager.nixosModules.default ];

  config = {
    system.stateVersion = "24.05";
    zramSwap.enable = true;

    boot = {
      loader = {
        timeout = 0;
        efi.canTouchEfiVariables = true;
        systemd-boot.editor = false;
      };

      supportedFilesystems = [ "zfs" ];
      kernelPackages = mkForce config.boot.zfs.package.latestCompatibleLinuxPackages;

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
    users.users = builtins.mapAttrs
      (name: val: {
        name = if val.name != null then val.name else name;
        isNormalUser = true;
        extraGroups = if val.isAdmin then [ "wheel" ] else [ ];
        hashedPasswordFile = config.age.secrets."users/${name}/passwordHash".path;
        openssh.authorizedKeys.keys = [ val.publicKey ];
      })
      cfg.users;

    environment.etc."machine-id".text = cfg.machine.id;
    networking.hostId = builtins.substring 0 8 cfg.machine.id; # for ZFS
    networking.hostName = cfg.machine.name;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
      hostKeys = [{
        path = cfg.machine.secretKey;
        type = "ed25519";
      }];
    };

    console.keyMap = cfg.machine.keyMap;
    i18n.defaultLocale = cfg.machine.locale;
    i18n.extraLocaleSettings.LC_TIME = cfg.machine.timeLocale;
    time.timeZone = cfg.machine.timeZone;

    environment.etc."nixos".source = src; # link config source to /etc/nixos
    services.journald.extraConfig = "SystemMaxUse=500M"; # limit journal size
    systemd.extraConfig = "DefaultTimeoutStopSec=10s"; # fix systemd being annoying

    nix.settings = {
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

    # pin nixpkgs to NIX_PATH
    environment.etc."nix/channel".source = self.inputs.nixpkgs.outPath;
    nix.nixPath = mkForce [ "nixpkgs=/etc/nix/channel" ];

    # pin nixpkgs to system flake registry
    nix.registry.nixpkgs.to = pipe "${self}/flake.lock" [
      builtins.readFile
      builtins.fromJSON
      (f: f.nodes.${f.nodes.${f.root}.inputs.nixpkgs}.locked)
    ];
  };
}
