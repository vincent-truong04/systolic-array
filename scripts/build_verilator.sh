#!/usr/bin/env bash
# Build Verilator from source into ~/tools/verilator/<version> (no sudo needed).
# Why: Ubuntu 26.04 apt ships 5.032, but cocotb 2.1.0 supports Verilator >= 5.036.
# Prereq (once, needs sudo):  sudo apt install autoconf
# Usage: scripts/build_verilator.sh [tag] [jobs]     e.g. scripts/build_verilator.sh v5.052 8
set -euo pipefail
TAG=${1:-v5.052}
JOBS=${2:-8}               # modest: 12 GB RAM laptop
SRC=~/tools/src/verilator
PREFIX=~/tools/verilator/${TAG#v}

command -v autoconf >/dev/null || { echo "autoconf missing: sudo apt install autoconf"; exit 1; }

mkdir -p ~/tools/src
[ -d "$SRC" ] || git clone https://github.com/verilator/verilator "$SRC"
cd "$SRC"
git fetch --tags -q
git checkout -q "$TAG"
git clean -xfdq            # fresh tree for this tag
autoconf
./configure --prefix="$PREFIX"
make -j"$JOBS"
make install
echo
echo "Installed: $("$PREFIX/bin/verilator" --version)"
echo "Add to ~/.bashrc:  export PATH=$PREFIX/bin:\$PATH"
