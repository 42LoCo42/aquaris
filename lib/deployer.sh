#!/usr/bin/env bash
set -euo pipefail
log() { echo -e "\e[1;32m$*...\e[m"; }
x() { (
	set -x
	"$@"
); }

host="root@192.168.122.195" # TODO
ssh-copy-id "$host"

if [ -e "machines/@name@/hardware.nix" ]; then
	log "Uploading installer"
	x nix copy @installer@ --to "ssh://$host"

	log "Starting installer"
	x ssh -t "$host" @installer@
else
	log "Creating hardware configuration"
	x ssh "$host" nixos-generate-config \
		--show-hardware-config --no-filesystems \
		>"machines/@name@/hardware.nix"
	git add -N .

	log "Restarting deployer"
	exec nix run ".#@name@-installer"
fi
