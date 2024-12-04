#!/usr/bin/env bash

log() { echo -e "\e[1;32m$1...\e[m"; }
x() { (
	set -x
	"$@"
); }

mnt="${MNT-/mnt}"
machineKey="keys/@name@.key"

doFormat() {
	log "Running formatter"
	@format@
}

doMount() {
	log "Running mount script"
	@mount@
}

doInstall() {
	log "Installing machine key"
	x mkdir -p "$(dirname "$mnt/@key@")"
	x cp "$machineKey" "$mnt/@key@"

	log "Mounting nom-overlay"
	overlay="nom-overlay-$RANDOM"
	x mkdir -p "$mnt/nix/store"
	x mount -t overlay -o "lowerdir=/nix/store:$mnt/nix/store" "$overlay" "/nix/store"
	trap 'umount -l "$overlay"' EXIT

	log "Mounting proc"
	x umount "$mnt/proc" || :
	x mount -m -t proc proc "$mnt/proc"

	log "Copying system configuration"
	nix copy "@self@" --to "$mnt"

	log "Building system configuration"
	sys="$(nom build \
		--extra-experimental-features "nix-command flakes" \
		--extra-substituters "@subs@" \
		--extra-trusted-public-keys "@keys@" \
		--store "$mnt" --no-link --print-out-paths \
		"@self@#nixosConfigurations.@name@.config.system.build.toplevel")"

	log "Setting the system profile"
	x nix-env --store "$mnt" --set --profile "$mnt/nix/var/nix/profiles/system" "$sys"

	log "Installing the boot loader"
	nixos-enter --root "$mnt" -c "$(
		cat <<-EOF
			touch /etc/NIXOS
			mount -m -t tmpfs tmpfs /tmp
			@installBootLoader@
		EOF
	)"
}

usage() {
	cat <<-EOF
		Usage: $0 [actions...]
		Actions:
		  -f, --format      Format disks
		  -m, --mount       Mount the configured filesystems
		  -k, --key <path>  Alternative machine key location
		  -i, --install     Build & install the system
	EOF
}

(($#)) || {
	usage
	exit
}

while (($#)); do
	case "$1" in
	-f | --format) doFormat ;;
	-m | --mount) doMount ;;
	-k | --key)
		shift
		machineKey="$1"
		;;
	-i | --install) doInstall ;;

	*)
		echo "Unknown option $1"
		usage
		exit 1
		;;
	esac

	shift
done
