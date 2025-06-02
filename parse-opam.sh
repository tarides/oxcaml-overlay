#!/usr/bin/env bash
set -e
set -u
set -o pipefail
pkg=$1
rev=$(grep /archive/ packages/$pkg/*/opam | grep -o '[[:xdigit:]]\{40\}')
echo "$pkg.rev = \"$rev\";"
padded=$(printf %-43s $pkg|tr ' ' 'A' |tr _ +)
echo "$pkg.hash = \"sha256-$padded=\";"
