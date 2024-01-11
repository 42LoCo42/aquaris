inputs:
let
  inherit (inputs.nixpkgs.lib)
    mapAttrsToList
    mkOption
    pipe
    recursiveUpdate
    types;
  inherit (types)
    int
    str
    submodule;
in
{
  recMerge = builtins.foldl' recursiveUpdate { };

  substituteAll = file: vars:
    let
      pairs = mapAttrsToList (k: v: { inherit k v; }) vars;
      srcs = map (i: "@${i.k}@") pairs;
      dsts = map (i: toString i.v) pairs;
    in
    pipe file [
      builtins.readFile
      (builtins.replaceStrings srcs dsts)
    ];

  my-utils = rec {
    mkHomeLinks = pairs: pipe pairs [
      (map (pair: ''
        mkdir -p "${dirOf pair.dst}"
        ln -sfT "${pair.src}" "${pair.dst}"
      ''))
      (builtins.concatStringsSep "\n")
      (inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ])
    ];

    ##### Simple ADT library #####

    adtExample =
      let
        # simple type (no parameters)
        foo.options.abc = mkOption {
          type = int;
          default = 123;
        };

        # complex type: takes val -> taking { name, ... } is optional,
        # but helps with tagging (which is required!)
        bar = val: { name, ... }: adt.addTag name {
          options = {
            xyzzy = mkOption {
              type = str;
              default = val;
            };
          };
        };

        choices = {
          inherit foo;
          bar = bar "hello";
        };
        foobarT = adt.mkOneOf choices; # type constructor
        foobar = adt.mkTagger choices; # value constructor group
      in
      mkOption {
        type = foobarT;
        default = foobar.bar { }; # select a value constructor
      };

    adt =
      let
        addTag = name: val: recursiveUpdate val {
          options._tag = mkOption {
            type = str;
            default = name;
          };
        };

        mkMod = name: val:
          if builtins.isAttrs val
          then submodule (addTag name val)
          else submodule val;

        mkOneOf = choices: pipe choices [
          (mapAttrsToList (name: opt:
            let mod = mkMod name opt; in
            mod // { check = v: mod.check v && v._tag == name; }
          ))
          types.oneOf
        ];

        mkTagger = builtins.mapAttrs
          (name: _: v: recursiveUpdate v { _tag = name; });
      in
      { inherit addTag mkOneOf mkTagger; };
  };
}
