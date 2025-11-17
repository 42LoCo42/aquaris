# show template
jst() {
	r="$1"; t="$2"; shift 2

	jj log \
		--no-pager \
		--no-graph \
		--ignore-working-copy \
		-r "$r" -T "$t" "$@"
}

# find bookmark
jfb() {
	jst '..@' 'if(
		self.local_bookmarks().len() > 0,
			self.change_id() ++ " " ++
			self.local_bookmarks().map(|x| x.name()) ++ "\n",
		"")' \
	| while read -r rev name rest; do
		if [ -z "$rest" ]; then
			echo "$name"
			return 0
		fi

		echo -n "[1;31mMore than one bookmark at [m$(
			jst "$rev" 'self.change_id().shortest(8)' --color always) :: " >&2
		jst "$rev" 'self.local_bookmarks() ++ "\n"' >&2
		return 1
	done

	echo "[1;31mReached root commit without finding a bookmark[m" >&2
	return 1
}

# find (valid) commit: has content & description
jfc() {
	jst '..@' '
		self.change_id() ++ " " ++
		self.empty() || self.description().trim().len() <= 0 ++ "\n"' \
	| while read -r rev skip; do
		"$skip" && continue
		echo "$rev"
		return 0
	done

	echo "[1;31mReached root commit without finding a valid commit[m" >&2
	return 1
}

# "intelligent" push - finds a bookmark and moves it to the first non-empty commit
jps() {
	if [ -n "$1" ]; then bmk="$1"; else bmk="$(jfb)" || return 1; fi
	rev="$(jfc)" || return 1

	jj bookmark set "$bmk" -r "$rev"
	jj git push --all
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
	args=("--no-pager")
	if jj config get aquaris.status-ignore-working-copy >/dev/null 2>&1; then
		args+=("--ignore-working-copy")
	fi
	jj status "${args[@]}"
	echo
	jj log  "${args[@]}"
}

MAGIC_ENTER_JJ_COMMAND=' jsl'
MAGIC_ENTER_GIT_COMMAND=' git status -u'
MAGIC_ENTER_OTHER_COMMAND=' l'
