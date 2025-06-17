#!/usr/bin/env bash
set -eEuo pipefail

# prepend nixpkgs to arguments that are only package names
nixpkgs="$(realpath "/etc/nix/channel")"
packages=()
run=nix
for i in "$@"; do
	if grep -q '^-' <<<"$i"; then
		: # do nothing on options
	elif grep -q '[:#]' <<<"$i"; then
		# flake type (:) and/or fragment (#) was specified!
		# this might be a thirdparty (non-nixpkgs) package
		# we want to see details about potential builds
		run=nom
	else
		# packages from nixpkgs do not require nix-output-monitor
		# since they should always be available in cached form
		i="$nixpkgs#$i"
	fi

	echo "Using $i"
	packages+=("$i")
done

# launch shell
if [ -z "${AQUARIS_USE+x}" ]; then
	export AQUARIS_USE=1
	export PATH="/AQUARIS_USE:$PATH"
fi
exec "$run" shell -L "${packages[@]}"
