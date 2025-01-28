# show template
jst() {
	jj log --limit 1 --no-graph --ignore-working-copy -T "$@"
}

# bookmark find
jbf() {
	rev="@"
	while "$(jst '!self.root()' -r "$rev")"; do
		bookmarks=()

		while read -r line; do bookmarks+=("$line"); done \
			< <(jst 'self.bookmarks().map(|x| x.name() ++ "\n").join("")' -r "$rev")

		case "${#bookmarks[@]}" in
		0) rev="$rev-" ;;

		1)
			echo "${bookmarks[1]}"
			return 0
			;;

		*)
			id="$(jst 'self.change_id().shortest(8) ++ "\n"' -r "$rev" --color always)"
			echo "[1;31mMore than 1 bookmark at commit[m $id" >&2

			jst 'self.change_id().shortest(8)' -r "$rev" |
				xargs -I% jj log --ignore-working-copy -r "%-..@" >&2

			return 1
			;;
		esac
	done

	echo "[1;31mReached root commit without finding a bookmark[m" >&2
	return 1
}

# "intelligent" push - sets bookmark-find to first non-empty commit
jps() {
	if [ -n "$1" ]; then
		bookmark="$1"
	else
		bookmark="$(jbf)" || return 1
	fi

	rev="@"
	while "$(jst 'self.empty()' -r "$rev")"; do rev="$rev-"; done

	jj bookmark set "$bookmark" -r "$rev"
	jj git push
}

# clone from github
jcg() {
	repo="$(sed -E 's|^https://github.com/([^/]+/[^/]+).*|git@github.com:\1.git|' <<< "$1")"
	shift
	jj git clone --colocate "$repo" "$@"
}

# describe-then-new
jdn() {
	jj describe -m "$@"
	jj new
}

##### functions for magic enter #####

# check root
jcr() {
	jj root >/dev/null 2>&1
}

# status-then-log
jsl() {
	jj status --no-pager
	echo
	jj log --no-pager
}

MAGIC_ENTER_GIT_COMMAND='   if jcr; then jsl; else git status; fi'
MAGIC_ENTER_OTHER_COMMAND=' if jcr; then jsl; else l;          fi'
