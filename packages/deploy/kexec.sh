#!/usr/bin/env bash

d="$(mktemp -d)"
curl -L "$1" | tar xz -C "$d"

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
