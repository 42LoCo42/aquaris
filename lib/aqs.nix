nixpkgs: { users, machines }:
let
  inherit (nixpkgs.lib)
    filterAttrs
    mapAttrsToList
    pipe;

  ##### toplevel: all keys #####

  getKeys = set: pipe set [
    builtins.attrValues
    (map (i: i.publicKey or ""))
  ];

  toplevel = getKeys users ++ getKeys machines;

  ##### user secrets: for that user & the machines they are part of #####

  isUserInMachine = userN: machine: pipe machine [
    (m: builtins.attrNames (m.admins or { }) ++ builtins.attrNames (m.users or { }))
    (builtins.elem userN)
  ];

  machineKeysForUser = userN: pipe machines [
    (filterAttrs (_: isUserInMachine userN))
    (mapAttrsToList (_: m: m.publicKey or ""))
  ];

  user = builtins.mapAttrs (userN: userV: [ userV.publicKey or "" ] ++ machineKeysForUser userN) users;

  ##### machine secrets: for that machine & its admins #####

  adminKeys = machine: mapAttrsToList (_: a: a.publicKey or "") (machine.admins or { });
  machine = builtins.mapAttrs (_: m: [ m.publicKey or "" ] ++ adminKeys m) machines;
in
{ inherit toplevel user machine; }
