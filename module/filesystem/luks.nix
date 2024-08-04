util: { lib, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything functionTo listOf str;

  mapper = device: "/dev/mapper/${baseNameOf device}";
in
{
  options = {
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
        cryptsetup luksFormat \
          ${builtins.concatStringsSep " " config.formatOpts} \
          ${device}

        cryptsetup open \
          ${builtins.concatStringsSep " " config.openOpts} \
          ${device} ${baseNameOf device}

        ${config.content._create (mapper device)}
      '';
    };

    _mounts = mkOption {
      type = functionTo anything;
      readOnly = true;
      default = device: util.merge [
        { luks.${baseNameOf device} = { inherit device; }; }
        (config.content._mounts (mapper device))
      ];
    };
  };
}
