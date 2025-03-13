#!/usr/bin/env bash

cfg="$(realpath "${NIXOS_CONFIG_DIR-$HOME/config}")"
declare new

err() {
	echo "[1;31m$1![m" >&2
}

log() {
	echo "[1;32m$1...[m"
}

build() {
	log "Building configuration"
	new="$(nom build --no-link --print-out-paths \
		"$cfg#nixosConfigurations.@name@.config.system.build.toplevel")"

	nvd diff /run/current-system "$new"
}

update() {
	log "Updating configuration"
	nix flake update --flake "$cfg"
}

activate() {
	if [ -z "${new+x}" ]; then
		build
	fi

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
