#!/usr/bin/env bash
set -euo pipefail
[ -n "${IN_NIX_SHELL+x}" ] && exit

IFS=: read -ra path <<<"$PATH"

getExtraPkgNames() {
	for i in "${path[@]}"; do
		awk '{
			if(match($0, /^\/nix\/store\/[^-]+-([^\/]+)/, a)) {
				print a[1]
			} else {
				exit 1
			}
		}' <<<"$i" || break
	done
}
readarray -t extraPkgNames < <(getExtraPkgNames)

((${#extraPkgNames[@]} == 0)) && exit
echo "[m[1m${extraPkgNames[*]}[m"
