#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../pkg"
rm -rf src pkg ./*.pkg.tar.*
makepkg -f --nodeps --noconfirm
# yay, the AUR helper the Store and updates build with, isn't in Arch's repositories: it's built here from the
# AUR's yay-bin and goes out in Vyntaris's repository with the rest, so every system has it from the start.
aur="$(mktemp -d)"; trap 'rm -rf "$aur"' EXIT
git clone -q --depth 1 https://aur.archlinux.org/yay-bin.git "$aur/yay-bin"
(cd "$aur/yay-bin" && makepkg -f --nodeps --noconfirm >/dev/null)
cp "$aur"/yay-bin/yay-bin-[0-9]*.pkg.tar.zst .
ls -1 "$PWD"/vyntaris-*.pkg.tar.zst "$PWD"/yay-bin-*.pkg.tar.zst
