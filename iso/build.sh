#!/usr/bin/env bash
set -euo pipefail
SUDO=sudo; [ "$(id -u)" -eq 0 ] && SUDO=""
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$REPO/iso"
WORK="${WORK:-$HOME/.cache/vyntaris-iso}"
OUT="${OUT:-$ISO/out}"

command -v mkarchiso >/dev/null || $SUDO pacman -S --needed --noconfirm archiso

pkgfile="${VYNTARIS_PKG:-}"
if [ -z "$pkgfile" ]; then
    "$REPO/tools/package.sh"
    pkgfile="$(ls -t "$REPO"/pkg/vyntaris-*.pkg.tar.zst | head -n1)"
fi

$SUDO rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
profile="$WORK/profile"
cp -r /usr/share/archiso/configs/releng "$profile"

cp -rT "$ISO/airootfs" "$profile/airootfs"
sed -i 's/ kms / /' "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
grep -q ' kms ' "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf" && { echo "kms is still in the ISO's initramfs" >&2; exit 1; }
repo="$profile/airootfs/opt/vyntaris-repo"
mkdir -p "$repo"
cp "$pkgfile" "$repo/"
repo-add -q "$repo/vyntaris.db.tar.gz" "$repo/$(basename "$pkgfile")"

for p in efibootmgr git hyprland quickshell kitty inter-font ttf-jetbrains-mono noto-fonts networkmanager; do
    grep -qx "$p" "$profile/packages.x86_64" || echo "$p" >> "$profile/packages.x86_64"
done

inst="$profile/airootfs/usr/share/desktop-installer"
mkdir -p "$inst/config" "$inst/components"
cp "$REPO/config/installer/shell.qml" "$REPO/config/installer/hyprland.lua" "$inst/"
cp "$REPO/config/installer/config/Config.qml" "$REPO/config/quickshell/config/Theme.qml" \
    "$REPO/config/quickshell/config/Tr.qml" "$REPO/config/quickshell/config/Palettes.js" "$inst/config/"
cp "$REPO"/config/quickshell/components/* "$inst/components/"
cp -r "$REPO/config/quickshell/i18n" "$inst/"
cp "$REPO/config/quickshell/assets/wallpapers/default.jpg" "$inst/wallpaper.jpg"
cp "$REPO/packages.txt" "$ISO/base-packages" "$inst/"
mkdir -p "$profile/airootfs/usr/share/icons"
cp -a "$REPO/config/icons/Bibata-Modern-Ice" "$profile/airootfs/usr/share/icons/"

wants="$profile/airootfs/etc/systemd/system"
rm -f "$wants/multi-user.target.wants/iwd.service" "$wants/multi-user.target.wants/systemd-networkd.service" \
    "$wants/sockets.target.wants/systemd-networkd.socket" "$wants/dbus-org.freedesktop.network1.service" \
    "$wants/network-online.target.wants/systemd-networkd-wait-online.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$wants/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service "$wants/dbus-org.freedesktop.nm-dispatcher.service"

"$REPO/system/pacman-candy.sh" "$profile/pacman.conf"

# Every package an install can ask for, with all it depends on, for installing without internet.
offline="$profile/airootfs/opt/vyntaris-offline"
mkdir -p "$offline" "$WORK/offline-db"
{ cat "$profile/pacman.conf"; printf '\n[vyntaris]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$repo"; } > "$WORK/offline.conf"
# shellcheck source=iso/base-packages
. "$ISO/base-packages"
mapfile -t apps < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$REPO/packages.txt" | grep -v '^$')
$SUDO pacman --config "$WORK/offline.conf" --dbpath "$WORK/offline-db" --cachedir "$offline" -Syw --noconfirm \
    "${BASE[@]}" "${UCODE[@]}" "${FIRMWARE[@]}" "${FIRMWARE_NVIDIA[@]}" "${FIRMWARE_AMD[@]}" "${apps[@]}"
$SUDO rm -rf "$WORK/offline-db"
$SUDO rm -f "$offline"/*.sig
$SUDO repo-add -q "$offline/offline.db.tar.gz" "$offline"/*.pkg.tar.*
du -sh "$offline"
install -Dm644 "$REPO/system/os-release" "$profile/airootfs/etc/os-release"
grep -rl "Arch Linux" "$profile/efiboot" "$profile/grub" "$profile/syslinux" 2>/dev/null |
    xargs -r sed -i 's/Arch Linux install medium/Vyntaris/g; s/Arch Linux/Vyntaris/g' || true
install -Dm644 "$profile/pacman.conf" "$profile/airootfs/etc/pacman.conf"
printf '\n[vyntaris]\nSigLevel = Optional TrustAll\nServer = file:///opt/vyntaris-repo\n' >> "$profile/airootfs/etc/pacman.conf"

version="$(bsdtar -xOf "$pkgfile" .PKGINFO | sed -n 's/^pkgver = \(.*\)-[^-]*$/\1/p')"
[ -n "$version" ] || version="$(cat "$REPO/VERSION")"
# The installer says which Vyntaris it puts on, at the top.
echo "$version" > "$inst/version"
sed -i \
    -e 's/^iso_name=.*/iso_name="vyntaris"/' \
    -e "s/^iso_version=.*/iso_version=\"$version\"/" \
    -e 's/^iso_label=.*/iso_label="VYNTARIS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' \
    -e 's/^iso_application=.*/iso_application="Vyntaris live and install medium"/' \
    -e '/^file_permissions=(/a\  ["/usr/local/bin/install-desktop"]="0:0:755"' \
    -e '/^file_permissions=(/a\  ["/usr/local/bin/fix-keyring"]="0:0:755"' \
    -e '/^file_permissions=(/a\  ["/usr/local/bin/installer"]="0:0:755"' \
    -e '/^file_permissions=(/a\  ["/usr/local/bin/installer-shell"]="0:0:755"' \
    -e '/^file_permissions=(/a\  ["/usr/local/bin/repair-desktop"]="0:0:755"' \
    "$profile/profiledef.sh"

echo 'kernel_params_x86_64="cow_spacesize=2G"' >> "$profile/profiledef.sh"
# With the packages on it the system is too big to copy into memory at every boot.
grep -rl 'archisobasedir=%INSTALL_DIR%' "$profile/efiboot" "$profile/grub" "$profile/syslinux" 2>/dev/null |
    xargs -r sed -i 's/archisobasedir=%INSTALL_DIR%/& copytoram=n/'

$SUDO mkarchiso -v -r -w "$WORK/work" -o "$OUT" "$profile"
$SUDO chown "$(id -u):$(id -g)" "$OUT"/*.iso
ls -l "$WORK"/work/efiboot.img "$WORK"/work/iso/arch/x86_64/airootfs.sfs "$WORK"/work/iso/arch/boot/x86_64/* 2>/dev/null || true
$SUDO rm -rf "$WORK"
ls -lh "$OUT"/*.iso
