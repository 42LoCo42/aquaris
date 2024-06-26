#!/usr/bin/env bash

log() { echo -e "\e[1;32m$1...\e[m"; }
x() { (
	set -x
	"$@"
); }

mnt="${MNT-/mnt}"

doFormat() {
	log "Running formatter"
	@format@
}

doMount() {
	log "Running mount script"
	@mount@
}

doInstall() {
	log "Mounting nom-overlay"
	overlay="nom-overlay-$RANDOM"
	x mkdir -p "$mnt/nix/store"
	x mount -t overlay -o "lowerdir=/nix/store:$mnt/nix/store" "$overlay" "/nix/store"
	trap 'umount -l "$overlay"' EXIT

	log "Building system configuration"
	sys="$(
		nom build \
			--extra-experimental-features "nix-command flakes" \
			--extra-substituters "@subs@" \
			--extra-trusted-public-keys "@keys@" \
			--store "$mnt" --no-link --print-out-paths \
			"@self@#nixosConfigurations.@name@.config.system.build.toplevel"
	)"

	log "Installing the system"
	nixos-install \
		--no-channel-copy \
		--no-root-password \
		--root "$mnt" \
		--system "$sys"
}

usage() {
	cat <<-EOF
		Usage: $0 [actions...]
		Actions:
		  -f, --format     Format disks
		  -m, --mount      Mount the configured filesystems
		  -i, --install    Build & install the system
	EOF
}

(($#)) || {
	usage
	exit
}

while (($#)); do
	case "$1" in
	-f | --format | f*) doFormat ;;
	-m | --mount | m*) doMount ;;
	-i | --install | i*) doInstall ;;

	*)
		echo "Unknown option $1"
		usage
		exit 1
		;;
	esac

	shift
done
