let
  aquaris = builtins.fetchGit {
    url = "https://github.com/42LoCo42/aquaris";
    rev = "9cd2424f773394d508b49e2792072dbb71331321";
  };
in
import "${aquaris}/lib/secrets.nix" ./..
