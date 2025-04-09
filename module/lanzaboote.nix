{ pkgs, lib, config, ... }:
let
  inherit (lib)
    getExe
    mkDefault
    mkIf
    mkMerge
    mkOption
    ;
  inherit (lib.types)
    bool
    lines
    listOf
    nullOr
    path
    str
    ;

  inherit (config.aquaris.persist) root;

  # cached in obscura
  lanza = builtins.getFlake "github:42LoCo42/lanzaboote/4bcbae99c48270ccd6fe8f09a5aca4b32bb0a76a";

  cfg = config.boot.lanzaboote;

  sbctl-conf = pkgs.writeText "sbctl.conf" ''
    keydir:     ${cfg.pkiBundle}/keys
    guid:       ${cfg.pkiBundle}/GUID
    files_db:   ${cfg.pkiBundle}/files.json
    bundles_db: ${cfg.pkiBundle}/bundles.json
  '';
in
{
  imports = [ "${lanza}/nix/modules/lanzaboote.nix" ];

  options.boot.lanzaboote = {
    createKeys = mkOption {
      description = "Automatically create secure boot keys";
      type = bool;
      default = true;
    };

    ##### PCR policy signing #####

    pcrPolicyKey = mkOption {
      description = "Path to the PCR policy secret signing key";
      type = nullOr path;
      default = "${root}/var/lib/pcr-policy.key";
    };

    createPCRPolicyKey = mkOption {
      description = "Automatically create the PCR policy key";
      type = bool;
      default = true;
    };

    ##### extended lzbt configuration #####

    extraArgs = mkOption {
      description = "Extra arguments to pass to lzbt";
      type = listOf str;
      default = [ ];
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

  config = mkIf config.aquaris.machine.secureboot (mkMerge [
    # lanzaboote configuration
    {
      boot.lanzaboote = {
        enable = mkDefault true;
        configurationLimit = mkDefault config.aquaris.machine.keepGenerations;
        pkiBundle = mkDefault "${root}/var/lib/sbctl";

        extraArgs = mkMerge [
          (mkIf (cfg.pcrPolicyKey != null) [
            "--pcr-policy-key=${cfg.pcrPolicyKey}"
          ])
        ];

        preCommands = mkMerge [
          (mkIf cfg.createKeys ''
            if [ ! -f "${cfg.pkiBundle}/GUID" ]; then
              ${getExe pkgs.sbctl} create-keys --config ${sbctl-conf}
            fi
          '')

          (mkIf cfg.createPCRPolicyKey ''
            if [ ! -f "${cfg.pcrPolicyKey}" ]; then
              ${getExe pkgs.openssl} genrsa \
                -out "${cfg.pcrPolicyKey}" 2048
            fi
          '')
        ];

        package = pkgs.writeShellApplication {
          name = "lzbt";
          text = ''
            shift # get rid of "install" positional argument
            ${cfg.preCommands}
            ${getExe lanza.packages.${pkgs.system}.lzbt} \
              install ${toString cfg.extraArgs} "$@"
            ${cfg.postCommands}
          '';
        };
      };

      environment.etc."sbctl/sbctl.conf".source = sbctl-conf;
    }

    # support services for PCR policy logic
    {
      boot.initrd = {
        supportedFilesystems = [ config.fileSystems."/boot".fsType ];

        systemd = {
          extraBin = {
            objcopy = "${pkgs.binutils}/bin/objcopy";
            systemd-pcrextend = "${pkgs.systemd}/lib/systemd/systemd-pcrextend";
          };

          mounts = [
            (
              let boot = config.fileSystems."/boot"; in {
                what = boot.device;
                where = "/boot";
                type = boot.fsType;
                options = builtins.concatStringsSep "," boot.options;
              }
            )
          ];

          services = {
            extract-pcr-sections = {
              script = ''
                entry="/boot/EFI/Linux/$(
                  cat /sys/firmware/efi/efivars/LoaderEntrySelected-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f \
                  | tail -c+5 | tr -d '\0')"

                objcopy -O binary -j .pcrpkey "$entry" "/run/systemd/tpm2-pcr-public-key.pem"
                objcopy -O binary -j .pcrsig  "$entry" "/run/systemd/tpm2-pcr-signature.json"
              '';

              unitConfig.DefaultDependencies = "no";

              after = [ "boot.mount" ];
              bindsTo = [ "boot.mount" ];

              before = [ "cryptsetup.target" ''system-systemd\x2dcryptsetup.slice'' ];
              requiredBy = [ "cryptsetup.target" ''system-systemd\x2dcryptsetup.slice'' ];

              wantedBy = [ "initrd.target" ];
            };

            systemd-pcrphase-initrd = {
              unitConfig = {
                Description = "TPM PCR Barrier (initrd)";
                Documentation = "man:systemd-pcrphase-initrd.service(8)";
                DefaultDependencies = "no";
                Conflicts = [
                  "shutdown.target"
                  "initrd-switch-root.target"
                ];
                After = "tpm2.target";
                Before = [
                  "sysinit.target"
                  "cryptsetup-pre.target"
                  "cryptsetup.target"
                  "shutdown.target"
                  "initrd-switch-root.target"
                  "systemd-sysext.service"
                ];
                ConditionPathExists = "/etc/initrd-release";
                ConditionSecurity = "measured-uki";
              };

              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = "yes";
                ExecStart = "/bin/systemd-pcrextend --graceful enter-initrd";
                ExecStop = "/bin/systemd-pcrextend --graceful leave-initrd";
              };

              wantedBy = [ "initrd.target" ];
            };
          };
        };
      };
    }
  ]);
}
