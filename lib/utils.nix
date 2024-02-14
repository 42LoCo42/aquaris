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
  my-utils = rec {
    mkHomeLinks = pairs: pipe pairs [
      (map (pair: ''
        mkdir -p "${dirOf pair.dst}"
        ln -sfT "${pair.src}" "${pair.dst}"
      ''))
      (builtins.concatStringsSep "\n")
      (inputs.home-manager.lib.hm.dag.entryAfter [ "linkGeneration" ])
    ];

    recMerge = builtins.foldl' recursiveUpdate { };

    subsF = { file, func, subs ? { } }:
      let
        pairs = mapAttrsToList (k: v: { inherit k v; }) subs;
        srcs = map (i: "@${i.k}@") pairs;
        dsts = map (i: toString i.v) pairs;
      in
      pipe file [
        builtins.readFile
        (builtins.replaceStrings srcs dsts)
        (func (baseNameOf file))
      ];

    subsT = file: subs: subsF {
      inherit file subs;
      func = _: text: text;
    };

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
          (mapAttrsToList (name: val:
            let mod = mkMod name val; in
            mod // { check = v: mod.check v && v._tag == name; }
          ))
          types.oneOf
        ];

        mkTagger = choices: pipe choices [
          (mapAttrsToList (name: val: {
            "${name}" = v: recursiveUpdate v { _tag = name; };
            is.${name} = v: v._tag == name;
            tag.${name} = name;
          }))
          (builtins.foldl' recursiveUpdate { })
        ];
      in
      { inherit addTag mkOneOf mkTagger; };
  };
}
