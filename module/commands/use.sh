#!/usr/bin/env bash
args=()
nixpkgs="$(realpath "/etc/nix/channel")"
for arg in "$@"; do
	# prepend nixpkgs if the argument is only a package name
	grep -q '^-\|[#:]' <<<"$arg" || {
		arg="$nixpkgs#$arg"
		echo "Using $arg"
	}
	args+=("$arg")
done

export IN_USE_SHELL=1
exec nix shell -L "${args[@]}"
