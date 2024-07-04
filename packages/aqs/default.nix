pkgs: pkgs.writeShellApplication {
  name = "aqs";
  text = builtins.readFile ./aqs.sh;
  runtimeInputs = with pkgs; [
    age
    jq
  ];
}
