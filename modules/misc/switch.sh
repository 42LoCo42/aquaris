#!/usr/bin/env bash
set -e
echo "Evaluating configuration..."
new="$("@nom@" \
	build --no-link --print-out-paths \
	"path:$HOME/config#nixosConfigurations.\"@name@\".config.system.build.toplevel")"
"@nvd@" diff "/run/current-system" "$new"
echo "Activating configuration..."
sudo nix-env --set --profile /nix/var/nix/profiles/system "$new"
sudo "$new/bin/switch-to-configuration" switch
