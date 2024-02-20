#!/usr/bin/env bash
set -euo pipefail
src="@src@"

fail() {
	echo "[1;31m$1[m" >&2
}

die() {
	fail "$1!"
	exit 1
}

info() {
	echo "[1;32m$1[m"
}

work() {
	echo "[1;33m$1...[m"
}

prompt() {
	declare var
	read "$@" -rp "[1;34m${var^}:[m " "${var?}" || exit 1
	[ -n "${!var}" ]
}

promptPW() {
	prompt -s
	ret="$?"
	echo
	return "$ret"
}

sshKeygen() {
	out="keys/$1.key"
	mkdir -p "$(dirname "$out")"
	[ -e "$out" ] && die "Key $out already exists"
	ssh-keygen -t ed25519 -f "$out" -q -N "" </dev/null
	read -r type data _ <"$out.pub"
	rm "$out.pub"
	echo "$type $data"
}

encrypt() {
	out="secrets/$1.age"
	mkdir -p "$(dirname "$out")"
	age -r "$2" -o "$out"
}

userF="$(mktemp)"
machineF="$(mktemp)"
trap 'rm -f "$userF" "$machineF"' EXIT

info "Welcome to the Aquaris setup wizard!"
work "Leaving names empty ends the current step"
echo "========================================="

info "Step 1: Users"

while var=username prompt; do
	declare password repeated
	while true; do
		var=password promptPW || {
			fail "No password provided"
			continue
		}
		var=repeated promptPW || {
			fail "No password provided"
			continue
		}

		if [ "$password" == "$repeated" ]; then break; fi
		fail "Passwords don't match!"
	done

	work "Generating SSH keypair"
	pub="$(sshKeygen "users/$username")"
	encrypt "users/$username/secretKey" "$pub" <"keys/users/$username.key"

	work "Generating password hash"
	mkpasswd -s <<<"$password" | encrypt "users/$username/passwordHash" "$pub"

	export username pub
	envsubst <"$src/user.nix" >>"$userF"
done

info "Step 2: Machines"

while var=machine prompt; do
	adminsA=()
	# shellcheck disable=SC2209
	while var=admin prompt; do
		adminsA+=("$admin")
	done

	usersA=()
	while var=user prompt; do
		usersA+=("$user")
	done

	work "Generating a machine ID"
	id="$(systemd-id128 new)"

	work "Generating SSH keypair"
	pub="$(sshKeygen "machines/$machine")"

	export machine id pub

	if ((${#adminsA[@]})); then
		admins="$(printf '"%s" ' "${adminsA[@]}")"
	else
		admins=""
	fi
	export admins

	if ((${#usersA[@]})); then
		users="$(printf '"%s" ' "${usersA[@]}")"
	else
		users=""
	fi
	export users

	envsubst <"$src/machine.nix" >>"$machineF"
done

work "Generating flake"
users="$(<"$userF")"
machines="$(<"$machineF")"
export users machines
envsubst <"$src/template.nix" | nixpkgs-fmt | tee flake.nix

work "Finalizing"
aqs -r # rekey all secrets so the machines can read them
