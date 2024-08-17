util: { lib, config, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types) anything coercedTo functionTo listOf nullOr package path str;

  mapper = device: "/dev/mapper/${baseNameOf device}";

  opts =
    if config.keyFile == null
    then [ "--key-file" ''"$key"'' ]
    else [ "--key-file" config.keyFile ];
in
{
  options = {
    keyFile = mkOption {
      description = "Path to the key file";
      type = nullOr (coercedTo package (x: x.outPath) path);
      default = null;
    };

    formatOpts = mkOption {
      description = "Options for cryptsetup luksFormat";
      type = listOf str;
    };

    openOpts = mkOption {
      description = "Options for cryptsetup open";
      type = listOf str;
    };

    content = mkOption {
      description = "Partition content";
      inherit (util.fs) type;
    };

    _create = mkOption {
      type = functionTo str;
      readOnly = true;
      default = device:
        let
          ask = ''
            key="$(mktemp)"
            while true; do
              p1="$(systemd-ask-password "Password for ${device}:")"
              p2="$(systemd-ask-password "Verify password:")"

              if [ "$p1" == "$p2" ]; then
                echo -n "$p1" > "$key"
                break
              else
                echo "[1;31mError:[m Passwords don't match!" >&2
              fi
            done
          '';

          join = builtins.concatStringsSep " ";
        in
        (if config.keyFile == null then ask else "") + ''
          cryptsetup luksFormat --batch-mode ${join config.formatOpts} ${device}
          cryptsetup open ${join config.openOpts} ${device} ${baseNameOf device}
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

  config = {
    formatOpts = opts;
    openOpts = opts;
  };
}
