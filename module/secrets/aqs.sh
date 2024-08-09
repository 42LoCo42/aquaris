#!/usr/bin/env bash

cmd="$1"
shift

case "$cmd" in
decrypt)
	secrets="$1"
	secretKey="$2"
	outputDir="$3"
	decryptDir="$4"

	while read -r entry; do
		name="$(jq -r '.key' <<<"$entry")"
		source="$(jq -r '.value.source' <<<"$entry")"
		out="$outputDir/$name"

		echo "[aqs] decrypting $name"
		mkdir -p "$(dirname "$out")"
		(
			umask u=r,g=,o=
			age -i "$secretKey" -o "$out" -d "$source"
		) &
	done < <(jq -rc 'to_entries[]' "$secrets")

	wait
	ln -sfT "$outputDir" "$decryptDir"

	echo "[aqs] collecting garbage"
	find "$decryptDir.d" -mindepth 1 -maxdepth 1 |
		{ grep -v "$outputDir" || :; } |
		xargs rm -rfv
	;;

chown)
	secrets="$1"
	outputDir="$2"

	while read -r entry; do
		name="$(jq -r '.key' <<<"$entry")"
		user="$(jq -r '.value.user' <<<"$entry")"
		group="$(jq -r '.value.group' <<<"$entry")"
		mode="$(jq -r '.value.mode' <<<"$entry")"
		out="$outputDir/$name"

		echo "[aqs] $name: $user:$group $mode"
		chown "$user:$group" "$out"
		chmod "$mode" "$out"
	done < <(jq -rc 'to_entries[]' "$secrets")
	;;

protect)
	secretKey="$1"

	chown 0:0 "$secretKey"
	chmod 0400 "$secretKey"
	;;
esac
