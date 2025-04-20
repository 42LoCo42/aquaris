{ flake-utils, nixpkgs, ... }:
let
  inherit (nixpkgs.lib)
    fileContents
    filterAttrs
    ifEnable
    mapAttrsToList
    mkOption
    pipe
    recursiveUpdate
    splitString
    ;
  inherit (nixpkgs.lib.types)
    oneOf
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
        oneOf
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
