#!/usr/bin/env bash

url="${1//SYSTEM/@system@}"

d="$(mktemp -d)"
curl -L "$url" | tar xz -C "$d"

ip --json addr | jq -r '
   .[]
   | .ifname as $i
   | .addr_info[]
   | "\($i) \(.local)/\(.prefixlen)"
' | while read -r i a; do
	echo "dynamic IP fix for $a on $i"
	ip addr change dev "$i" "$a"
done

exec "$d/kexec/run"
