#!/usr/bin/env bash

# find commit all
jfca() {
	jj log \
		--no-graph \
		--no-pager \
		--ignore-working-copy \
		--template 'stringify(self.change_id()) ++ "\n"' \
		--color always \
		--revision "$1"
}

# find commit one
jfco() {
	jj show \
		--no-patch \
		--no-pager \
		--ignore-working-copy \
		--template 'stringify(self.change_id()) ++ "\n"' \
		--color always \
		"$1"
}

# "intelligent" push
jps() {
	# give merge commits a default description
	jfca '..@ & merges() & mutable() & description(exact:"")' |
		while read -r rev; do
			jj describe --message "merge" "$rev"
		done

	# find next pushable commit
	to="$(jfco 'closest_pushable()')" || return 1

	if [ -z "$to" ]; then
		echo "Nothing to push!" >&2
		return
	fi

	if (($#)); then
		# if we have explicit bookmarks, set those
		jj bookmark set --revision "$to" "$@"
	elif [ -z "$(jfca 'closest_bookmark()')" ]; then
		# if there are no bookmarks, create main
		jj bookmark set --revision "$to" "main"
	else
		# move bookmarks from nearest commit
		from="$(jfco 'closest_bookmark()')" || return 1
		jj bookmark move --from "$from" --to "$to"
	fi

	jj git push --all --deleted
	git push --tags --force
}

# clone from github
jcg() {
	repo="$(sed -E 's|^https://github.com/([^/]+/[^/]+).*|git@github.com:\1.git|' <<<"$1")"
	shift
	jj git clone --colocate "$repo" "$@"
}

# describe-then-new
jdn() {
	jj describe -m "$@"
	jj new
}

# show content
jsc() {
	rev="$(jfco 'closest_pushable()')" || return 1
	jj show "$rev"
}

##### functions for magic enter #####

# check root
jcr() {
	jj root >/dev/null 2>&1
}

# status-then-log
jsl() {
	args=("--no-pager")
	if jj config get aquaris.status-ignore-working-copy >/dev/null 2>&1; then
		args+=("--ignore-working-copy")
	fi
	jj status "${args[@]}"
	echo
	jj log "${args[@]}"
}

MAGIC_ENTER_JJ_COMMAND=' jsl'
MAGIC_ENTER_GIT_COMMAND=' git status -u'
MAGIC_ENTER_OTHER_COMMAND=' l'
