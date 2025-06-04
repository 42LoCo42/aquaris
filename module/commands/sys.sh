#!/usr/bin/env bash
set -eEuo pipefail

cfg="$(realpath "${NIXOS_CONFIG_DIR-$HOME/config}")"
declare new

err() {
	echo "[1;31m$1![m" >&2
}

log() {
	echo "[1;32m$1...[m" >&2
}

warn() {
	echo "[1;33m$1![m" >&2
}

build() {
	sudo=""
	args=()

	log "Checking binary cache configuration"
	active="$(grep -oP 'substituters = \K.*' /etc/nix/nix.conf | tr ' ' '\n' | sort)"

	config="$(nix eval "$cfg#nixosConfigurations.@name@.config.nix.settings" --raw \
		--apply 'x: builtins.toJSON { inherit (x) substituters trusted-public-keys; }')"

	wanted="$(jq -r '.substituters[]' <<<"$config" | sort)"

	if [ "$active" != "$wanted" ]; then
		warn "Binary cache configuration has changed"

		diff \
			--unified=999 --color=always \
			<(echo "$active") <(echo "$wanted") |
			tail -n+4 | sed 's|^|  |' || :

		pubkeys="$(jq -r '."trusted-public-keys" | join(" ")' <<<"$config")"

		warn "Executing build as root"
		sudo="sudo"
		args+=(
			--option substituters "$(tr '\n' ' ' <<<"$wanted")"
			--option trusted-public-keys "$pubkeys"
		)
	fi

	log "Building configuration"
	new="$($sudo nom build --no-link --print-out-paths "${args[@]}" \
		"$cfg#nixosConfigurations.@name@.config.system.build.toplevel")"

	nvd diff /run/current-system "$new"
}

update() {
	log "Updating configuration"
	nix flake update --flake "$cfg"
}

activate() {
	if [ -z "${new+x}" ]; then build; fi

	log "Activating configuration"
	sudo nix-env --set --profile /nix/var/nix/profiles/system "$new"
	@keepGenerations@
	sudo "$new/bin/switch-to-configuration" "$1"
}

for i in "$@"; do
	case "$i" in
	update | u) update ;;

	boot | b) activate boot ;;
	rebuild | r) activate switch ;; # legacy alias
	switch | s) activate switch ;;
	test | t) activate test ;;

	*)
		err "[1;31mUnknown action $i![m"
		exit 1
		;;
	esac
done
