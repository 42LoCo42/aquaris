src: { config, lib, ... }:
let
  inherit (lib) mkIf mkMerge mkOption types;
  inherit (types) bool path str;
  cfg = config.aquaris.sys-settings;
in
{
  options.aquaris.sys-settings = {
    hostName = mkOption {
      type = str;
    };

    machineID = mkOption {
      type = str;
    };

    sshHostKeyPath = mkOption {
      type = path;
      default = "/etc/ssh/ssh_host_ed25519_key";
    };

    linkCurrentConfig = mkOption {
      type = bool;
      default = true;
    };
  };

  config = mkMerge [
    {
      system.stateVersion = "24.05";
      zramSwap.enable = true;

      boot = {
        tmp.useTmpfs = true;

        loader = {
          timeout = 0;
          efi.canTouchEfiVariables = true;
          systemd-boot.editor = false;
        };

        kernelParams = [
          "vt.default_red=0x28,0xcc,0x98,0xd7,0x45,0xb1,0x68,0xa8,0x92,0xfb,0xb8,0xfa,0x83,0xd3,0x8e,0xeb"
          "vt.default_grn=0x28,0x24,0x97,0x99,0x85,0x62,0x9d,0x99,0x83,0x49,0xbb,0xbd,0xa5,0x86,0xc0,0xdb"
          "vt.default_blu=0x28,0x1d,0x1a,0x21,0x88,0x86,0x6a,0x84,0x74,0x34,0x26,0x2f,0x98,0x9b,0x7c,0xb2"
        ];

        initrd.systemd.enable = true;
      };

      environment.etc."machine-id".text = cfg.machineID;
      networking.hostId = builtins.substring 0 8 cfg.machineID;
      networking.hostName = cfg.hostName;

      services = {
        openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "no";
          };
          hostKeys = [{
            path = cfg.sshHostKeyPath;
            type = "ed25519";
          }];
        };

        journald.extraConfig = "SystemMaxUse=500M";
      };

      systemd.extraConfig = "DefaultTimeoutStopSec=10s";
    }

    (mkIf cfg.linkCurrentConfig {
      system.activationScripts.link-current-config.text = ''
        rm -rf /etc/nixos
        ln -s "${src}" /etc/nixos
      '';
    })
  ];
}
