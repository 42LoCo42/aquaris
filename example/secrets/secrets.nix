let aquaris = builtins.fetchGit { url = "https://github.com/42LoCo42/aquaris"; }; in
import "${aquaris}/lib/secrets.nix" ./..
