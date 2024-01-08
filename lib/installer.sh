#!/usr/bin/env bash
set -euo pipefail
log() { echo -e "\e[1;32m$1...\e[m"; }
x() { (
	set -x
	"$@"
); }

log "Formatting disks"
disko --no-deps -m disko -f "@src@#@name@"

log "Mounting nom-overlay"
name="nom-overlay-$RANDOM"
x mkdir -p /mnt/nix/store
x mount "$name" /nix/store -t overlay -o lowerdir=/nix/store:/mnt/nix/store
trap 'umount -l "$name"' EXIT

log "Building system configuration"
sys="$(
	nom build \
		--extra-experimental-features "nix-command flakes" \
		--extra-substituters "@subs@" \
		--extra-trusted-public-keys "@keys@" \
		--store /mnt --no-link --print-out-paths \
		"@src@#nixosConfigurations.@name@.config.system.build.toplevel"
)"

log "Installing the system"
nixos-install --no-channel-copy --no-root-password --system "$sys"
