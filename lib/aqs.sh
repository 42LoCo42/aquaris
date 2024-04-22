#!/usr/bin/env bash
set -euo pipefail

err() {
	echo "[1;31merror:[m $1" >&2
}

die() {
	err "$1"
	exit 1
}

help() {
	cat <<-EOF
		Usage: $0 [flags...]

		Flags:
		    -d, --decrypt  <file>    Decrypt a secret file to stdout
		    -e, --edit     <file>    Edit a secret file with \$EDITOR ($EDITOR)
		    -h, --help               Print this help
		    -i, --identity <file>    Extra identity to use for decryption
		    -r, --rekey    [path]    Rekey file or all secret files below path

		If only a filepath is given, --edit is assumed by default.

		Decryption uses all <flake>/keys/*.key files as default identities.
		More can be provided via --identity (repeable).

		All paths must be part of an Aquaris flake,
		which is autodetected by traversing the path upwards.
		If no path is given for --rekey, the current directory is used.

		Secret types depending on the filepath:
		    toplevel:    <flake>/secrets/<secretName>.age
		                 Encrypted for all keys.

		    user:        <flake>/secrets/users/<userName>/<secretName>.age
		                 Encrypted for this user & the machines they are part of.

		    machine:     <flake>/secrets/machines/<machineName>/<secretName.age>
		                 Encrypted for the machine & its admins.
	EOF
}

findFlake() {
	flake="$(realpath -m "$1")"

	while test ! -e "$flake/flake.nix"; do
		flake="$(dirname "$flake")"
		[ "$flake" == "/" ] && die "Path $1 is not part of a flake"
	done

	aqscfg="$(mktemp)"
	trap 'rm "$aqscfg"' EXIT
	nix eval --raw --apply builtins.toJSON "path:$flake#aqscfg" >"$aqscfg"
	echo "Aquaris flake found in $flake" >&2

	if [ -d "$flake/keys" ]; then
		mapfile -t foundIDs < <(find "$flake/keys" -name '*.key')
		echo "Default identities:" >&2
		printf "  %s\n" "${foundIDs[@]}" >&2
	fi
}

getCategory() {
	secret="$(realpath -m "$1")"
	secret="${secret#"$flake"}"
	[[ "$secret" =~ ^/secrets/users/([^/]+)/.+\.age$ ]] && echo "user.\"${BASH_REMATCH[1]}\"" && return
	[[ "$secret" =~ ^/secrets/machines/([^/]+)/.+\.age$ ]] && echo "machine.\"${BASH_REMATCH[1]}\"" && return
	[[ "$secret" =~ ^/secrets/[^/]+\.age$ ]] && echo "toplevel" && return
	die "Path $1 is not a valid secret"
}

# NOTE: always call edit in a subprocess to not override findFlake's exit trap
edit() {
	category="$(getCategory "$1")"

	tmp="$(mktemp)"
	trap 'rm "$tmp"' EXIT

	[ -e "$1" ] && decrypt "$1" "$tmp"
	"$EDITOR" "$tmp"
	jq -r ".${category}[]" <"$aqscfg" | age -e -R - -o "$1" "$tmp"
}

decrypt() {
	mapfile -td " " args < <(echo -n "${foundIDs[@]/#/-i }" "${extraIDs[@]/#/-i }")
	age "${args[@]}" -o "$2" -d "$1"
}

(($#)) || {
	err "No flags provided!"
	help
	exit 1
}

while (($#)); do
	case "$1" in
	-d | --decrypt)
		shift
		findFlake "$1"
		decrypt "$1" -
		;;

	-e | --edit)
		shift
		findFlake "$1"
		(edit "$1")
		;;

	-h | --help)
		help
		exit
		;;

	-i | --identity)
		shift
		extraIDs+=("$1")
		;;

	-r | --rekey)
		shift
		path="${1-.}"
		findFlake "$path"

		if [ -f "$path" ]; then
			echo "Rekeying $path"
			(EDITOR=: edit "$path")
		elif [ -d "$path" ]; then
			i=0
			j="$(nproc)"
			while read -r path; do
				i=$((i % j))
				((i++ == 0)) && wait

				echo "Rekeying $path"
				EDITOR=: edit "$path" &
			done < <(find "$path" -name '*.age')
			wait
		else
			die "Invalid path $path"
		fi
		;;

	-*)
		err "Unknown flag: $1"
		help >&2
		exit 1
		;;

	*)
		findFlake "$1"
		(edit "$1")
		;;
	esac
	shift
done
