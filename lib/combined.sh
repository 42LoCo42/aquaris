#!/usr/bin/env bash
set -euo pipefail

err() { echo -e "\e[1;31m$1\e[m" >&2; }
log() { msg "$1..."; }
msg() { echo -e "\e[1;32m$1\e[m" >&2; }

x() { (
	set -x
	"$@"
); }

user="leonsch"
host="192.168.122.254"
conn="$user@$host"

kexecURL="http://192.168.122.1:8000/kexec.tgz"

conf="@self@#nixosConfigurations.\"@name@\""
root="/mnt"

shopt -s expand_aliases
alias nix='nix --extra-experimental-features "nix-command flakes"'

##### deployment #####

deploySSHKeys() {
	log "Deploying SSH keys"
	x ssh-copy-id "$conn"
}

deployMasterKey() {
	deploySSHKeys
	log "Deploying @name@ master key"
	x scp "keys/@name@.key" "$conn:@name@.key"
}

deployInstaller() {
	deploySSHKeys
	log "Deploying installer"
	x nix copy "$0" --to "ssh://$conn"
}

##### kexec #####

kexecRemote() {
	deploySSHKeys

	log "Deploying installer for kexec step"
	name="aquaris-installer-$RANDOM$RANDOM"
	x scp "$0" "$conn:$name"

	tmp="$(ssh "$conn" mktemp)"
	x ssh -t "$conn" "bash $name kexecLocal"

	while sleep 3; do
		if ssh "$conn" -o ConnectTimeout=1 test ! -e "$tmp"; then
			msg "Machine has rebooted!"
			break
		else
			log "Waiting for reboot"
		fi
	done
}

kexecLocal() {
	log "Downloading kexec tarball"
	cd "$(mktemp -d)" || exit
	curl -fsSL "$kexecURL" | tar xzv

	log "Performing kexec"
	sudo ./kexec/run
}

##### target actions #####

doFormat() {
	log "Formatting disk"
	nix run "$conf.config.aquaris.filesystem._format"
}

doMount() {
	log "Mounting disks"
	nix run "$conf.config.aquaris.filesystem._mount" "$root"
}

doNomOverlay() {
	log "Mounting nom-overlay"
	name="nom-overlay-$RANDOM"
	x mkdir -pv "$root/nix/store"
	x mount \
		-t overlay \
		-o lowerdir="/nix/store:$root/nix/store" \
		"$name" "/nix/store"
	trap 'umount -l "$name"' EXIT
}

doCopyMasterKey() {
	log "Copying @name@ master key to target"
	mkdir -pv "$(dirname "$root/@masterKeyPath@")"
	x cp "@name@.key" "$root/@masterKeyPath@"
}

doBuild() {
	log "Building system configuration"
	nom build \
		--extra-experimental-features "nix-command flakes" \
		--extra-substituters "@subs@" \
		--extra-trusted-public-keys "@keys@" \
		--store "$root" --no-link --print-out-paths \
		"$conf.config.system.build.toplevel"
}

doInstall() {
	doMount
	doNomOverlay
	doCopyMasterKey
	sys="$(doBuild)"
	log "Installing the system"
	nixos-install \
		--no-channel-copy --no-root-password \
		--system "$sys" --root "$root"
}

# doUpdate() {
# 	sys="$(doBuild)"
# 	nvd diff "/run/current-system" "$sys"
# 	log "Activating configuration..."
# 	sudo nix-env --set --profile /nix/var/nix/profiles/system "$sys"
# 	sudo "$sys/bin/switch-to-configuration" switch
# }

for i in "$@"; do
	case "$i" in
	deployMasterKey) deployMasterKey ;;

	kexec | kexecRemote) kexecRemote ;;
	kexecLocal) kexecLocal ;;

	format) doFormat ;;
	install) doInstall ;;
	# update) doUpdate ;;

	remote=*)
		deployInstaller
		x ssh -t "$conn" "$0" "${i#*=}"
		;;

	*)
		err "Unknown action $i"
		exit 1
		;;
	esac
done
