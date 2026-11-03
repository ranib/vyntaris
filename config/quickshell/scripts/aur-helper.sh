#!/bin/sh
# The AUR helper the Store builds with (yay), for when the install couldn't get it: vyntaris-setup builds it in the
# installer's chroot, often with no network or base-devel, and then skips it. base-devel and git first, then yay-bin
# built as you and installed. The log is in $XDG_RUNTIME_DIR/vyntaris-aur-helper.log.
{ command -v yay || command -v paru; } >/dev/null 2>&1 && exit 0
log="${XDG_RUNTIME_DIR:-/tmp}/vyntaris-aur-helper.log"
: > "$log"
if ! pacman -Q base-devel git >/dev/null 2>&1; then
    pkexec pacman -S --needed --noconfirm base-devel git >> "$log" 2>&1 || exit 1
fi
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
git clone -q --depth 1 https://aur.archlinux.org/yay-bin.git "$build/yay-bin" >> "$log" 2>&1 || exit 1
(cd "$build/yay-bin" && makepkg --noconfirm >> "$log" 2>&1) || exit 1
pkexec pacman -U --noconfirm "$build"/yay-bin/yay-bin-[0-9]*.pkg.tar.* >> "$log" 2>&1 || exit 1
# What came in only to build a package goes again, as vyntaris-user-setup sets it.
yay --save --removemake >/dev/null 2>&1 || true
