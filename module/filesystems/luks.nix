util: { lib, config, ... }:
let
  inherit (lib)
    flatten
    ifEnable
    join
    mkOption
    ;

  inherit (lib.types)
    anything
    bool
    functionTo
    listOf
    str
    ;

  mapper = device: "/dev/mapper/${baseNameOf device}";
in
{
  options = {
    tpmDecrypt = mkOption {
      description = "Should this device be decrypted using the TPM?";
      type = bool;
      default = false;
    };

    tpmMeasure = mkOption {
      description = "Should the LUKS identity be measured into PCR 15?";
      type = bool;
      default = false;
    };

    formatOpts = mkOption {
      description = "Options for cryptsetup luksFormat";
      type = listOf str;
      default = [ ];
    };

    openOpts = mkOption {
      description = "Options for cryptsetup open";
      type = listOf str;
      default = [ ];
    };

    content = mkOption {
      description = "Partition content";
      inherit (util.fs) type;
    };

    _create = mkOption {
      type = functionTo str;
      readOnly = true;
      default = device: ''
        key="$(mktemp)"

        cryptsetup luksFormat            \
          --batch-mode                   \
          --key-file "$key"              \
          ${join " " config.formatOpts}  \
          ${device}

        ${if !config.tpmDecrypt then "" else ''
          systemd-cryptenroll        \
            --tpm2-device auto       \
            --unlock-key-file "$key" \
            ${device}
        ''}

        cryptsetup open                \
          --batch-mode                 \
          --key-file "$key"            \
          ${join " " config.openOpts}  \
          ${device} ${baseNameOf device}

        ${config.content._create (mapper device)}
      '';
    };

    _mounts = mkOption {
      type = functionTo anything;
      readOnly = true;
      default = device: util.merge [
        {
          luks.${baseNameOf device} = {
            inherit device;

            allowDiscards = true;
            bypassWorkqueues = true;

            crypttabExtraOpts = flatten [
              "try-empty-password=yes"
              (ifEnable config.tpmDecrypt [ "tpm2-device=auto" ])
              (ifEnable config.tpmMeasure [ "tpm2-measure-pcr=yes" ])
            ];
          };
        }
        (config.content._mounts (mapper device))
      ];
    };
  };
}
