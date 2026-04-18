#!/usr/bin/env bash
set -euo pipefail

change_mode="${1:-}"
origin_directory="$(mktemp -d "/tmp/grog-changes-${change_mode}-origin.XXXXXX")"
cleanup_file=".grog-test-cleanup"
setup_complete=false

cleanup() {
	if [[ "$setup_complete" != "true" && -d "$origin_directory" ]]; then
		rm -rf "$origin_directory"
	fi
}

trap cleanup EXIT

cp -R grog.toml pkg "$origin_directory"/

initialize_origin() (
	cd "$origin_directory"
	git init --quiet
	git config user.email grog@example.com
	git config user.name Grog
	printf 'base\n' >pkg/source.txt
	git add .
	git commit --quiet -m base
)

case "$change_mode" in
jj)

	initialize_origin
	(
		cd "$origin_directory"
		jj git init --colocate --quiet
		jj git export --quiet
	)
	git_root="$(cd "$origin_directory" && jj git root)"
	rm -rf .git .jj grog.toml pkg
	git clone --quiet --filter=blob:none --no-checkout "file://$git_root" .
	git checkout --quiet HEAD
	jj git init --colocate --quiet
	printf 'changed\n' >pkg/source.txt
	;;
dirty)
	initialize_origin
	rm -rf .git .jj grog.toml pkg
	git clone --quiet --filter=blob:none --no-checkout "file://$origin_directory" .
	git checkout --quiet HEAD
	printf 'dirty\n' >pkg/source.txt
	;;
git)
	initialize_origin
	(
		cd "$origin_directory"
		printf 'changed\n' >pkg/source.txt
		git add .
		git commit --quiet -m changed
	)

	rm -rf .git .jj grog.toml pkg
	git clone --quiet --filter=blob:none --no-checkout "file://$origin_directory" .
	git checkout --quiet HEAD
	;;
*)
	printf 'usage: %s jj|dirty|git\n' "$0" >&2
	exit 2
	;;
esac

printf '%s\n' "$origin_directory" >"$cleanup_file"
setup_complete=true
