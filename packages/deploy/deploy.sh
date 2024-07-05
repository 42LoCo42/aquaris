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
		Usage: $0 [options...] <[user@]host> <flake#config>
		Options:
		  --kexec-url <url>    Alternative URL for kexec, SYSTEM will be replaced
		  --force-kexec        Always run kexec, even if target is nixos-installer
		  --show-hwconf        Show the target's hardware config & wait for keypress
		  --dont-format        Don't run the formatting step of the installer
		  --dont-mount         Don't run the mount step of the installer
		  --dont-reboot        Don't reboot after installing

		  --help    Show this help
	EOF
}

target=""
config=""

kexec_url="https://github.com/nix-community/nixos-images/releases/download/nixos-24.05/nixos-kexec-installer-noninteractive-SYSTEM.tar.gz"
force_kexec=0
show_hwconf=0
dont_format=0
dont_mount=0
dont_reboot=0

if ! (($#)); then
	usage
	exit
fi

while (($#)); do
	case "$1" in
	--kexec-url) shift && kexec_url="$1" ;;
	--force-kexec) force_kexec=1 ;;
	--show-hwconf) show_hwconf=1 ;;
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
		target="$1"
		config="$2"
		break
		;;
	esac
	shift
done

r() {
	"${ssh_cmd-ssh}" "$target" "$@"
}

log "Authorizing client SSH key"
ssh_cmd=ssh-copy-id r

log "Checking target platform"

target_kernel="$(r uname -s)"
if [ "$target_kernel" != "Linux" ]; then
	die "Target kernel is $target_kernel, not Linux"
fi

target_arch="$(r uname -m)"
case "$target_arch" in
x86_64) kexec="@kexec-amd@" ;;
aarch64) kexec="@kexec-arm@" ;;
*) die "Unsupported target architecture $target_arch" ;;
esac

target_root() {
	target="root@${target#*@}"
}

run_kexec() {
	cmd="$(
		cat <<-\EOF | sed -Ez 's|\n+| \&\& |g;'
			set -euo pipefail

			d="$(mktemp -d)"
			cat > "$d/bundle"
			sh "$d/bundle" -d "$d" >&2

			echo "$d"
		EOF
	):"

	log "Uploading kexec helper"
	d="$(r "$cmd" <"$kexec")"

	log "Running kexec helper as root"
	r -t sudo "$d/root/bin/kexec" "$kexec_url"

	target_root

	while ! r -o ConnectTimeout=3 -o PasswordAuthentication=no test ! -f "$d/bundle"; do
		log "Waiting to kexec to finish"
		sleep 2
	done
}

if ((force_kexec)); then
	dots=! log "kexec is forced"
	run_kexec
else
	log "Checking if kexec is required"

	os="$(r "sh -c 'source /etc/os-release && echo \${ID-unknown}-\${VARIANT_ID-unknown}'")"
	if [ "$os" == "nixos-installer" ]; then
		dots=! log "No, already running on nixos-installer"
	else
		dots=! log "Yes (OS = $os), proceeding with kexec"
		run_kexec
	fi
fi

##### at this point, we are root in a nixos-installer #####

target_root

if ((show_hwconf)); then
	log "Generating the hardware configuration"
	r nixos-generate-config --show-hardware-config --no-filesystems
	read -rp "[1;33mPress ENTER to continue... [m"
fi

log "Copying configuration $config to installer"
nix copy "$config" --to "ssh://$target" --substitute-on-destination

log "Evaluating config installer path"
bin="$(nix eval --raw "$config.bin")"

((dont_format)) || r "$bin" --format
((dont_mount)) || r "$bin" --mount

log "Copying extra files" # TODO copy an entire folder
rsync -azvP ./keys/example.key "$target:/mnt/persist/aqs.key"

r -t "$bin" --install # TTY for nom

if ! ((dont_reboot)); then
	log "Rebooting"
	r reboot
fi
