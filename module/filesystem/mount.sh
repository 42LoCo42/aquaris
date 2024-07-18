#!/usr/bin/env bash
mnt="${1-/mnt}"
zpool import -af

x() {
	(
		set -x
		"$@"
	)
}

while read -r src dst type option_str _; do
	if [ "$type" == "swap" ]; then
		x swapon "$src"
		continue
	fi

	declare -A options
	while IFS='=' read -r key val; do
		options[$key]="$val"
	done < <(tr ',' '\n' <<<"$option_str")

	if [[ -v options[bind] ]] || [[ -v options[rbind] ]]; then
		src="$mnt/$src"
		x mkdir -p -m "${options["x-aquaris.persist"]-0755}" "$src"
	fi

	# shellcheck disable=SC2001
	option_str="$(sed "s|=/|=$mnt/|g" <<<"$option_str")"

	x mount -m "$src" "$mnt/$dst" -t "$type" -o "$option_str"
done < <(grep -v '^#' <@fstab@ | grep .)
