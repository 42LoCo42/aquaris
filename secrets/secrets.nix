with import ./keys.nix; let
  allUsers = builtins.attrValues users;
  allMachines = builtins.attrValues machines;
  all = allUsers ++ allMachines;
in
{
  "akyuro.age".publicKeys = allUsers ++ [ machines.akyuro ];
  "janus.age".publicKeys = allUsers ++ [ machines.janus ];
  "password-hash.age".publicKeys = all;
}
