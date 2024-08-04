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
		  --key <path>         Path to the master encryption key

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
key=""

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
	--key) shift && key="$1" ;;

	--help) usage && exit ;;

	-*)
		err "Unknown flag $1"
		usage
		exit 1
		;;

	*)
		target="$1"
		config="$2"

		if [ -z "$key" ]; then
			echo "[1;33mWarning: --key is unset, secrets won't be readable![m"
		fi

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

log "Gathering facts"
while IFS='=' read -r var val; do
	echo "$var = $val"
	declare "$var=$val"
done < <(
	r <<-\EOF
		echo "target_kernel=$(uname -s)"
		echo "target_arch=$(uname -m)"
		echo "target_uid=$(id -u)"
		echo "target_sudo=$(command -v sudo)"
		echo "target_doas=$(command -v doas)"
		echo "target_os=$(sh -c 'source /etc/os-release && echo "${ID-unknown}-${VARIANT_ID-unknown}"')"
	EOF
)

declare target_kernel target_arch target_uid target_os

if [ "$target_kernel" != "Linux" ]; then
	die "Target kernel is $target_kernel, not Linux"
fi

case "$target_arch" in
x86_64) kexec="@kexec-amd@" ;;
aarch64) kexec="@kexec-arm@" ;;
*) die "Unsupported target architecture $target_arch" ;;
esac

asroot=""
if [ "$target_uid" != "0" ]; then
	if [ -n "$target_sudo" ]; then
		asroot="$target_sudo"
	elif [ -n "$target_doas" ]; then
		asroot="$target_doas"
	else
		die "We are $target_uid and neither sudo nor doas exist"
	fi
fi

target_root() {
	target="root@${target#*@}"
}

run_kexec() {
	log "Uploading kexec helper"
	r "cat > aquaris-kexec" <"$kexec"

	log "Running kexec helper as root"
	r -t "$asroot sh aquaris-kexec $kexec_url"

	target_root

	while ! r \
		-o ConnectTimeout=3 \
		-o PasswordAuthentication=no \
		test -f network/addrs.json; do
		log "Waiting to kexec to finish"
		sleep 2
	done
}

if ((force_kexec)); then
	dots=! log "kexec is forced"
	run_kexec
elif [ "$target_os" != "nixos-installer" ]; then
	dots=! log "kexec is required"
	run_kexec
else
	dots=! log "kexec is not required"
fi

##### at this point, we are root in a nixos-installer #####

target_root

if ((show_hwconf)); then
	log "Generating the hardware configuration"
	r nixos-generate-config --show-hardware-config --no-filesystems
	read -rp "[1;33mPress ENTER to continue... [m"
fi

log "Copying configuration $config to target"
rsync -azvP --delete "$(nix eval --raw "$config.self")/" "$target:config/"

log "Building installer"
bin="$(r "cd config; nix build -L --no-link --print-out-paths \"$config\"")/bin/*"

((dont_format)) || r -t "$bin" --format # TTY for LUKS passwords
((dont_mount)) || r "$bin" --mount

if [ -n "$key" ]; then
	log "Copying master key from $key"
	keypath="/mnt/$(nix eval --raw "$config.keypath")"
	rsync -azvP "$key" "$target:$keypath"
	r "chown root:root $keypath && chmod 0400 $keypath"
fi

r -t "$bin" --install # TTY for nom

if ! ((dont_reboot)); then
	log "Rebooting"
	r reboot
fi
