#!/usr/bin/env bash

err() {
	echo "[1;31m$1![m" >&2
}

log() {
	echo "[1;32m$1${dots-...}[m"
}

die() {
	err "$1"
	exit 1
}

usage() {
	cat <<-EOF
		Usage: $0 [options...] <flake#config>
		Options:
		  -u, --user     Set target user
		  -h, --host     Set target host
		  -p, --port     Set target port
		  -k, --kexec    Set URL of kexec tarball

		  --force-kexec    Always run kexec, even if target is nixos-installer
		  --dont-format    Don't run the formatting step of the installer
		  --dont-mount     Don't run the mount step of the installer
		  --dont-reboot    Don't reboot after installing

		  --help    Show this help
	EOF
}

user="${USER-}"
host="${HOST-}"
port="${PORT-22}"
kexec="${KEXEC-https://github.com/nix-community/nixos-images/releases/download/nixos-24.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz}"
config="${CONFIG-}"

force_kexec=0
dont_format=0
dont_mount=0
dont_reboot=0

if ! (($#)); then
	usage
	exit
fi

while (($#)); do
	case "$1" in
	-u | --user) shift && user="$1" ;;
	-h | --host) shift && host="$1" ;;
	-p | --port) shift && port="$1" ;;
	-k | --kexec) shift && kexec="$1" ;;

	--force-kexec) force_kexec=1 ;;
	--dont-format) dont_format=1 ;;
	--dont-mount) dont_mount=1 ;;
	--dont-reboot) dont_reboot=1 ;;
	--help) usage && exit ;;

	-*)
		err "Unknown flag $1"
		usage
		exit 1
		;;

	*)
		if [ -n "$config" ]; then
			die "Only one config can be specified"
		fi

		config="$1"
		;;
	esac
	shift
done

[ -z "$user" ] && die "user is unset"
[ -z "$host" ] && die "host is unset"
[ -z "$port" ] && die "port is unset"
[ -z "$kexec" ] && die "kexec is unset"
[ -z "$config" ] && die "config is unset"

r() {
	"${ssh_cmd-ssh}" -p "$port" "$user@$host" "$@"
}

log "Authorizing client SSH key"
ssh_cmd=ssh-copy-id r

run_kexec() {
	cmd=":$(
		cat <<-\EOF | sed -Ez '
			s|\n+| \&\& |g;'"
			s|KEXEC|$kexec|"

			set -euo pipefail

			d="$(mktemp -d)"
			cat > "$d/bundle"
			sh "$d/bundle" -d "$d" >&2

			echo "$d"
		EOF
	):"

	log "Uploading kexec helper"
	d="$(r "$cmd" <@kexec@)"

	log "Running kexec helper as root"
	r -t sudo "$d/root/bin/kexec" "$kexec"

	while ! r -o ConnectTimeout=3 test ! -f "$d/bundle"; do
		log "Waiting to kexec to finish"
		sleep 2
	done
}

if ((force_kexec)); then
	dots=! log "kexec is forced"
	run_kexec
else
	log "Checking if kexec is required"

	target="$(r "sh -c 'source /etc/os-release && echo \$ID-\$VARIANT_ID'")"
	if [ "$target" == "nixos-installer" ]; then
		dots=! log "No, already running on nixos-installer"
	else
		dots=! log "Yes (target = $target), proceeding with kexec"
		run_kexec
	fi
fi

##### at this point, we are root in a nixos-installer #####

user="root"
bin="$(nix eval --raw "$config.outPath")/bin/*"

log "Copying configuration $config to installer"
nix copy "$config" --to "ssh://$user@$host" --substitute-on-destination

((dont_format)) || r "$bin" --format
((dont_mount)) || r "$bin" --mount

log "Copying extra files" # TODO copy an entire folder
rsync -azvP ./keys/example.key "$user@$host:/mnt/persist/aqs.key"

r -t "$bin" --install # TTY for nom

if ! ((dont_reboot)); then
	log "Rebooting"
	r reboot
fi
