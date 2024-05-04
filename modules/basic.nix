{ pkgs, config, lib, self, nixpkgs, home-manager, ... }:
let
  inherit (lib) mkForce mkOption types;
  inherit (types) attrsOf bool listOf nullOr path str submodule;
  cfg = config.aquaris;
  persist = cfg.persist.root;

  notSAL = lib.mkIf (! cfg.standalone);
in
{
  options.aquaris = {
    standalone = mkOption {
      type = bool;
      description = ''
        If enabled, all Aquaris modules that require explicit configuration
        (e.g. secrets, filesystem) will be disabled.
      '';
      default = false;
    };

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

          extraKeys = mkOption {
            type = listOf str;
            description = ''
              Extra SSH public keys for logins.
            '';
            default = [ ];
          };

          git = {
            name = mkOption { type = nullOr str; default = null; };
            email = mkOption { type = nullOr str; default = null; };
            key = mkOption { type = nullOr str; default = null; };
          };
        };
      }));
      default = { };
    };

    machine = {
      # these options will be inherited from ${self}/default.nix

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

      extraKeys = mkOption {
        type = listOf str;
        description = ''
          Extra SSH public keys for secrets
        '';
        default = [ ];
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

  imports = [ home-manager.nixosModules.default ];

  config = {
    system.stateVersion = "24.05";
    zramSwap.enable = true;

    # keep flake inputs from being garbage collected
    system.extraDependencies =
      let
        collect =
          { flake, visited ? [ ] }:
          if builtins.elem flake.narHash visited ||
            ! builtins.hasAttr "inputs" flake
          then [ ] else
            lib.pipe flake.inputs [
              builtins.attrValues
              (builtins.concatMap (input: collect {
                flake = input;
                visited = visited ++ [ flake.narHash ];
              }))
              (x: x ++ [ flake.outPath ])
              lib.unique
            ];
      in
      collect {
        flake = self;
      };

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
      (uN: uV: {
        name = if uV.name != null then uV.name else uN;
        isNormalUser = true;
        extraGroups = if uV.isAdmin then [ "wheel" "networkmanager" ] else [ ];
        hashedPasswordFile = notSAL config.aquaris.secrets."users/${uN}/passwordHash".outPath;
        openssh.authorizedKeys.keys = notSAL ([ uV.publicKey ] ++ uV.extraKeys);
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
      hostKeys = notSAL [{
        path = cfg.machine.secretKey;
        type = "ed25519";
      }];
    };

    console.keyMap = cfg.machine.keyMap;
    i18n.defaultLocale = cfg.machine.locale;
    i18n.extraLocaleSettings.LC_TIME = cfg.machine.timeLocale;
    time.timeZone = cfg.machine.timeZone;

    environment.etc."nixos".source = self; # link config source to /etc/nixos
    services.journald.extraConfig = "SystemMaxUse=500M"; # limit journal size

    systemd = {
      extraConfig = "DefaultTimeoutStopSec=10s"; # fix systemd being annoying

      # don't wait for network
      network.wait-online.enable = false;
      services."NetworkManager-wait-online".enable = false;
    };

    networking = {
      useNetworkd = true;
      networkmanager = {
        enable = true;
        plugins = lib.mkForce [ ];
      };
    };

    nix.package = pkgs.nixVersions.latest;
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
    environment.etc."nix/channel".source = nixpkgs.outPath;
    nix.nixPath = mkForce [ "nixpkgs=/etc/nix/channel" ];

    # pin nixpkgs to system flake registry
    # TODO maybe find a way to get repo info from the flake input?
    # the old way of reading our flake.lock didn't respect an overriden nixpkgs input
    # but at least flake.lock has repo info...
    nix.registry.nixpkgs.to = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      inherit (self.inputs.nixpkgs) rev;
    };
  };
}
