#!/usr/bin/env bash

url="${1//SYSTEM/@system@}"

curl -L "$url" | tar xz

ip --json addr | jq -r '
   .[]
   | .ifname as $i
   | .addr_info[]
   | "\($i) \(.local)/\(.prefixlen)"
' | while read -r i a; do
	echo "dynamic IP fix for $a on $i"
	ip addr change dev "$i" "$a"
done

exec kexec/run
