#!/usr/bin/env bash
set -eEuo pipefail

# 1. prepend nixpkgs to arguments that are only package names
nixpkgs="$(realpath "/etc/nix/channel")"
packages=()
for i in "$@"; do
	grep -q '^-\|[#:]' <<<"$i" || {
		i="$nixpkgs#$i"
		echo "Using $i"
	}
	packages+=("$i")
done

# 2. resolve package outputs
resolve() {
	# shellcheck disable=SC2016
	# --apply is not a shell expression
	nix eval --quiet --raw "$1" \
		--apply 'x: builtins.toJSON (map (o: x.${o}) x.outputs)' |
		jq -r '.[]'
}
export -f resolve
readarray -t outputs < \
	<(parallel --will-cite resolve ::: "${packages[@]}")

# 3. realise missing paths
realise() {
	if [ ! -e "$1" ]; then
		nix-store --realise "$1"
	fi
}
export -f realise
parallel --will-cite realise ::: "${outputs[@]}"

# 4. export friendly package list
out="$(for i in "${outputs[@]}"; do tail -c+45 <<<"$i"; done | paste -sd ' ')"
export USE_SHELL_PKGS="${USE_SHELL_PKGS+$USE_SHELL_PKGS }$out"

# 5. launch shell
exec nom-shell --command "$SHELL" --packages "${outputs[@]}"
