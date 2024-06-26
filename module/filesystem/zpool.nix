util: { lib, name, config, ... }:
let
  inherit (lib) mapAttrsToList mkOption pipe;
  inherit (lib.types) anything attrsOf str submodule;

  joinOpts = chr: options: pipe options [
    (o: if builtins.isAttrs o then (mapAttrsToList (name: val: "${name}=${val}")) o else o)
    (map (o: "-${chr} ${o}"))
    (builtins.concatStringsSep " ")
  ];

  dataset = import ./dataset.nix joinOpts;
in
{
  options = {
    name = mkOption {
      description = "Name of the zpool";
      type = str;
      default = name;
    };

    poolOpts = mkOption {
      description = "Options set on pool creation";
      type = attrsOf str;
    };

    rootOpts = mkOption {
      description = "Default dataset options";
      type = attrsOf str;
    };

    datasets = mkOption {
      description = "Datasets in this zpool";
      type = attrsOf (submodule (dataset config));
      default = { };
    };

    _create = mkOption {
      type = str;
      default = ''
        zpool create                       \
          ${joinOpts "o" config.poolOpts}  \
          ${joinOpts "O" config.rootOpts}  \
          ${config.name}                   \
          "''${zpool_${config.name}[@]}"
        ${util.getEntries (x: x._create) config.datasets}
      '';
    };

    _mounts = mkOption {
      type = anything;
      default = pipe config.datasets [
        builtins.attrValues
        (map (x: x._mounts))
        util.merge
      ];
    };
  };

  config = {
    poolOpts = {
      ashift = "12";
      autoexpand = "on";
      autoreplace = "on";
      autotrim = "on";
    };

    rootOpts = {
      acltype = "posix";
      compression = "zstd";
      dnodesize = "auto";
      mountpoint = "none";
      normalization = "formD";
      relatime = "on";
      xattr = "sa";
    };
  };
}
