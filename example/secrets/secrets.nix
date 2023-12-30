let
  # aquaris = builtins.fetchGit {
  #   url = "https://github.com/42LoCo42/aquaris";
  #   rev = "8b2651859d4ebc551f1de50a23876ba9e3fa513c";
  # };
  # aquaris = ./../..;
in
import "${aquaris}/lib/secrets.nix" ./..
