{ lib, ... }:
let
  inherit (lib)
    elemAt
    escapeShellArg
    filter
    flatten
    flip
    isList
    join
    mapAttrsToList
    mapNullable
    pipe
    singleton
    ;
in
{
  nixpkgs.overlays = singleton (_: pkgs: {
    # aqwrap <pkg> {
    #   env.<name> = { set, def, pre, suf } or null
    #   cmd = { pre, suf }
    #   dir = string
    #   paths = [ ... ]
    # }
    aqwrap = pkg: args: pipe args [
      (args:
        (flip mapAttrsToList (args.env or { }) (var: ops:
          let var' = escapeShellArg var; in
          if ops == null then "--unset ${var'}" else
          flip mapAttrsToList ops (op: val:
            let val' = escapeShellArg val; in {
              set = "--set ${var'} ${val'}";
              def = "--set-default ${var'} ${val'}";
              pre = "--prefix ${var'} ${escapeShellArg (elemAt val 0)} ${escapeShellArg (elemAt val 1)}";
              suf = "--suffix ${var'} ${escapeShellArg (elemAt val 0)} ${escapeShellArg (elemAt val 1)}";
            }.${op}))) ++

        (flip mapAttrsToList (args.cmd or { }) (op: val:
          let
            mk = flag: arg:
              if isList arg then map (mk flag) arg
              else "--${flag} ${escapeShellArg arg}";
          in
          {
            pre = mk "add-flag" val;
            suf = mk "append-flag" val;
          }.${op})) ++

        [ (mapNullable (dir: "--chdir ${escapeShellArg dir}") (args.dir or null)) ]
      )
      (filter (x: x != null))
      flatten
      (join " ")
      (cmd: pkgs.symlinkJoin {
        name = "${pkg.pname or pkg.name}-wrapped";
        paths = [ pkg ] ++ (args.paths or [ ]);
        nativeBuildInputs = with pkgs; [ makeBinaryWrapper ];
        postBuild = ''
          for file in $out/bin/*; do
            wrapProgram "$file" ${cmd}
          done
        '';
      })
    ];
  });
}
