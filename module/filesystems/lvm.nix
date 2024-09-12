util: { lib, name, config, ... }:
let
  inherit (lib)
    filterAttrs
    mkOption
    pipe
    ;
  inherit (lib.types)
    anything
    attrsOf
    functionTo
    nullOr
    str
    submodule
    ;

  mapper = vg: lv: "/dev/${vg}/${lv}";

  sizedVolumes = expect: pipe config.volumes [
    (filterAttrs (_: x: (x.size != null) == expect))
    (util.getEntries (x: x._create name))
  ];
in
{
  options = {
    name = mkOption {
      description = "Name of the Volume Group";
      type = str;
      default = name;
    };

    volumes = mkOption {
      description = "Set of Logical Volumes";
      type = attrsOf (submodule ({ name, config, ... }: {
        options = {
          name = mkOption {
            description = "Name of the Logical Volume";
            type = str;
            default = name;
          };

          size = mkOption {
            description = "Size of this LV (null for 100%)";
            type = nullOr str;
            default = null;
          };

          content = mkOption {
            description = "LV content";
            inherit (util.fs) type;
          };

          _create = mkOption {
            type = functionTo str;
            readOnly = true;
            default = vg: ''
              lvcreate \
                ${if config.size == null
                  then "-l 100%FREE"
                  else "-L ${config.size}"} \
                ${vg} -n ${name}

              ${config.content._create (mapper vg name)}
            '';
          };

          _mounts = mkOption {
            type = functionTo anything;
            readOnly = true;
            default = vg: config.content._mounts (mapper vg name);
          };
        };
      }));
      default = { };
    };

    _create = mkOption {
      type = str;
      readOnly = true;
      default = ''
        vgcreate ${name} "''${lvm_${name}[@]}"
        ${sizedVolumes true}
        ${sizedVolumes false}
      '';
    };

    _mounts = mkOption {
      type = anything;
      readOnly = true;
      default = pipe config.volumes [
        builtins.attrValues
        (map (x: x._mounts name))
        util.merge
      ];
    };
  };
}
