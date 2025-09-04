{ flake-utils, nixpkgs, ... }:
let
  inherit (nixpkgs.lib)
    all
    fileContents
    filterAttrs
    foldl'
    head
    ifEnable
    mapAttrsToList
    mergeOneOption
    mkOption
    pipe
    recursiveUpdate
    splitString
    tail
    ;
  inherit (nixpkgs.lib.types)
    str
    submodule
    ;

  subsFunc = { text, subs ? { } }:
    let
      pairs = mapAttrsToList (k: v: { inherit k v; }) subs;
      srcs = map (i: "@${i.k}@") pairs;
      dsts = map (i: toString i.v) pairs;
    in
    builtins.replaceStrings srcs dsts text;
in
rec {
  inherit (flake-utils.lib) eachDefaultSystem;

  merge = builtins.foldl' recursiveUpdate { };

  subs = subsFunc;

  subsF = { file, func, subs ? { } }: pipe file [
    builtins.readFile
    (text: subsFunc { inherit text subs; })
    (func (baseNameOf file))
  ];

  subsT = file: subs: subsF {
    inherit file subs;
    func = _: text: text;
  };

  readLines = file: pipe file [
    fileContents
    (x: ifEnable (x != "") (splitString "\n" x))
  ];

  importDir' = { default ? false, dirs ? true }: dir: pipe dir [
    builtins.readDir
    (filterAttrs (name: type:
      (type == "regular" && builtins.match ".*\.nix" name != null && (default || name != "default.nix")) ||
      (type == "directory" && dirs && builtins.pathExists "${dir}/${name}/default.nix")))
    builtins.attrNames
    (map (x: "${dir}/${x}"))
  ];

  importDir = importDir' { };

  ##### Simple ADT library #####

  adt =
    let
      either = t1: t2: (nixpkgs.lib.types.either t1 t2) // {
        # merge logic from last working commit
        # https://github.com/NixOS/nixpkgs/commit/648dbed1d6903931745babf6bf686b0631970538 working parent
        # https://github.com/NixOS/nixpkgs/commit/70ab11c2f2ed1c8375da40d891f428139146a05d broken child
        merge =
          loc: defs:
          let
            defList = map (d: d.value) defs;
          in
          if all (x: t1.check x) defList then
            t1.merge loc defs
          else if all (x: t2.check x) defList then
            t2.merge loc defs
          else
            mergeOneOption loc defs;
      };

      addTag = val: recursiveUpdate val {
        options._tag = mkOption {
          type = str;
          readOnly = true;
        };
      };

      mkModule =
        let
          gen = val:
            if builtins.isAttrs val
            then addTag val
            else if builtins.isFunction val
            then args: gen (val args)
            else if builtins.isPath val
            then gen (import val)
            else abort "unsupported ADT entry type ${builtins.typeOf val}";
        in
        val: submodule (gen val);

      mkType = choices: pipe choices [
        (mapAttrsToList (name: val:
          let mod = mkModule val; in
          mod // { check = v: mod.check v && v._tag == name; }
        ))
        (x: foldl' either (head x) (tail x))
      ];

      adt = choices: pipe choices [
        (mapAttrsToList (name: _: {
          is.${name} = v: v._tag == name;
          mk.${name} = v: recursiveUpdate v { _tag = name; };
          type = mkType choices;
        }))
        (builtins.foldl' recursiveUpdate { })
      ];
    in
    adt;
}
