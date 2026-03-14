: "${XDG_DATA_HOME:="${HOME}/.local/share"}"
declare -A direnv_layout_dirs

direnv_layout_dir() {
    local hash name
    echo "${direnv_layout_dirs[$PWD]:=$(
        hash="$(sha1sum - <<< "$PWD" | head -c40)"
        name="${PWD//[^a-zA-Z0-9]/-}"
        echo "${XDG_DATA_HOME}/direnv/layouts/${hash}${name}"
    )}"
}
