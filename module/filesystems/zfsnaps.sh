#!/usr/bin/env bash
{
	echo "NAME USED REFER"
	zfs list -t snapshot -o name,used,refer -j | jq -r '
		.datasets
		| map({
		  name,
		  used:  .properties.used.value,
		  refer: .properties.referenced.value,
		  sort:  .name | sub(
		    "^(?<name>[^@]+)@zfs-auto-snap_(?<type>[^-]+)-(?<time>[0-9h-]+)$";
		    "\(.name)-\(.time)-\(.type)")})
		| sort_by(.sort) | reverse[]
		| "\(.name) \(.used) \(.refer)"'
} | column -t | less
