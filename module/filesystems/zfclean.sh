#!/usr/bin/env bash
zfs list -t snapshot -H -o name |
	grep -v frequent |
	sudo xargs -I% zfs destroy -v %
