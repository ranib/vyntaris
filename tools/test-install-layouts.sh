#!/usr/bin/env bash
# Installs from an ISO into a VM on each kind of disk and starts the result, with this tree's installer.
# Each is about 15 minutes. Nothing leaves the VM, and it needs KVM, so it runs on a desktop:
#   tools/test-install-layouts.sh vyntaris.iso [name...]
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:?the ISO}"; shift
OUT="${VM_OUT:-$(mktemp -d "${TMPDIR:-/var/tmp}/vyntaris-layouts.XXXXXX")}"
PORT="${PORT:-8123}"
OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
OVMF_VARS=/usr/share/edk2/x64/OVMF_VARS.4m.fd

# name:disk:what is on it first:mode:partition:what should happen
ALL="foreign:new:foreign:partition:/dev/vda3:refused
erase:new:none:erase::starts
over-erase:keep:none:partition:lastroot:starts
again:keep:none:partition:lastroot:starts
win-part:new:windows-spare:partition:/dev/vda3:starts
leftover:keep:leftover:partition:lastroot:starts
free-again:keep:none:free::starts
win-free:new:windows:free::starts
noesp-part:new:no-esp:partition:/dev/vda2:starts"

mkdir -p "$OUT/boot" "$OUT/www"
bsdtar -xf "$ISO" -C "$OUT/boot" arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img || exit 1
options="$(bsdtar -xOf "$ISO" loader/entries/01-archiso-linux.conf | sed -n 's/^options *//p')"
cp "$R/iso/airootfs/usr/local/bin/install-desktop" "$OUT/www/install-desktop"
common=(-enable-kvm -cpu host -machine q35 -m 4096 -smp 4
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$OUT/vars.fd"
    -drive "file=$OUT/disk.qcow2,if=virtio,format=qcow2"
    -nic user,model=virtio-net-pci)
(cd "$OUT/www" && exec python3 -I -m http.server "$PORT" --bind 127.0.0.1 > /dev/null 2>&1) &
HTTP=$!
trap 'kill "$HTTP" 2>/dev/null' EXIT
sleep 1

cat > "$OUT/www/check.sh" <<'CHECK'
#!/bin/bash
exec > /dev/ttyS1 2>&1
echo "CI: BOOTED root=$(findmnt -no SOURCE / | sed 's/\[.*//')"
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,PARTLABEL,MOUNTPOINTS | sed 's/^/CI: /'
bootctl list --no-pager 2>&1 | grep -E 'title|source' | sed 's/^/CI: /'
echo "CI: DONE"
sync
systemctl poweroff
CHECK

prepare() {
    local esp='mount /dev/vda1 /mnt && mkdir -p /mnt/EFI/Microsoft/Boot && cp /usr/share/edk2-shell/x64/Shell_Full.efi /mnt/EFI/Microsoft/Boot/bootmgfw.efi && umount /mnt'
    local settle='partprobe /dev/vda; udevadm settle'
    case "$1" in
        none) ;;
        leftover) echo "sgdisk -n '0:0:+1G' -t 0:ea00 -c '0:Vyntaris boot' /dev/vda > /dev/null; $settle" ;;
        foreign) echo "sgdisk -Z /dev/vda > /dev/null
sgdisk -n 1:0:+100M -t 1:ef00 -c 1:EFI -n 2:0:+1G -t 2:ea00 -c 2:other-boot -n 3:0:+40G -t 3:8300 -c 3:spare /dev/vda > /dev/null; $settle
mkfs.fat -F 32 /dev/vda1 > /dev/null; mkfs.ext4 -qF -L spare /dev/vda3" ;;
        windows) echo "sgdisk -Z /dev/vda > /dev/null
sgdisk -n 1:0:+100M -t 1:ef00 -c 1:EFI -n 2:0:+6G -t 2:0700 -c 2:windows /dev/vda > /dev/null; $settle
mkfs.fat -F 32 /dev/vda1 > /dev/null; mkfs.ext4 -qF -L windows /dev/vda2; $esp" ;;
        windows-spare) echo "sgdisk -Z /dev/vda > /dev/null
sgdisk -n 1:0:+100M -t 1:ef00 -c 1:EFI -n 2:0:+6G -t 2:0700 -c 2:windows -n 3:0:+40G -t 3:8300 -c 3:spare /dev/vda > /dev/null; $settle
mkfs.fat -F 32 /dev/vda1 > /dev/null; mkfs.ext4 -qF -L windows /dev/vda2; mkfs.ext4 -qF -L spare /dev/vda3; $esp" ;;
        no-esp) echo "sgdisk -Z /dev/vda > /dev/null
sgdisk -n 1:0:+6G -t 1:0700 -c 1:windows -n 2:0:+40G -t 2:8300 -c 2:spare /dev/vda > /dev/null; $settle
mkfs.ext4 -qF -L windows /dev/vda1; mkfs.ext4 -qF -L spare /dev/vda2" ;;
    esac
}

monitor() {
    python3 -I -c "
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.sendall((sys.argv[2] + '\n').encode()); time.sleep(0.3)" "$OUT/monitor.sock" "$1"
}

failed=0
lastroot=""
while IFS=: read -r name disk prep mode part want; do
    if [ "$#" -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$name"; then continue; fi
    [ "$part" = lastroot ] && part="$lastroot"
    log="$OUT/$name"
    echo ":: $name"
    if [ "$disk" = new ]; then
        rm -f "$OUT/disk.qcow2"
        qemu-img create -q -f qcow2 "$OUT/disk.qcow2" 90G
        cp "$OVMF_VARS" "$OUT/vars.fd"; chmod u+w "$OUT/vars.fd"
    fi
    cat > "$OUT/www/auto.sh" <<AUTO
#!/bin/bash
exec > >(tee /dev/ttyS0) 2>&1
curl -fsSo /tmp/install-desktop http://10.0.2.2:$PORT/install-desktop && install -m755 /tmp/install-desktop /usr/local/bin/install-desktop
$(prepare "$prep")
INSTALL_MODE=$mode INSTALL_PART=$part \\
INSTALL_DISK=/dev/vda INSTALL_USER=tester INSTALL_PASSWORD=test INSTALL_HOSTNAME=vmtest \\
INSTALL_TIMEZONE=Europe/Belgrade INSTALL_KEYMAP=us INSTALL_LOCALE=en_US.UTF-8 INSTALL_YES=1 \\
    install-desktop 2>&1 | tee /tmp/install.out
result=\${PIPESTATUS[0]}
root="\$(grep -ao '/dev/vda[0-9]* → / ' /tmp/install.out | tail -n1 | cut -d' ' -f1)"
echo "NEW-ROOT=\$root"
if [ "\$result" = 0 ] && [ -n "\$root" ]; then
    opts=""; [ "\$(lsblk -no FSTYPE "\$root")" = btrfs ] && opts="-o subvol=@"
    mount \$opts "\$root" /mnt
    curl -fsSo /mnt/usr/local/bin/layout-check http://10.0.2.2:$PORT/check.sh && chmod 755 /mnt/usr/local/bin/layout-check
    printf '[Unit]\nAfter=multi-user.target\n[Service]\nType=simple\nExecStart=/usr/local/bin/layout-check\n' > /mnt/etc/systemd/system/layout-check.service
    ln -sf /etc/systemd/system/layout-check.service /mnt/etc/systemd/system/multi-user.target.wants/
    umount /mnt
fi
echo "INSTALL-RESULT=\$result"
sleep 2
poweroff
AUTO
    timeout 40m qemu-system-x86_64 "${common[@]}" -cdrom "$ISO" \
        -kernel "$OUT/boot/arch/boot/x86_64/vmlinuz-linux" -initrd "$OUT/boot/arch/boot/x86_64/initramfs-linux.img" \
        -append "$options console=tty0 console=ttyS0,115200 script=http://10.0.2.2:$PORT/auto.sh" \
        -display none -serial "file:$log-install.log" -monitor none
    result="$(grep -ao 'INSTALL-RESULT=[0-9]*' "$log-install.log" | tail -n1 | cut -d= -f2)"
    lastroot="$(grep -ao 'NEW-ROOT=[^[:space:]]*' "$log-install.log" | tail -n1 | cut -d= -f2)"

    if [ "$result" != 0 ]; then
        got=refused
    else
        rm -f "$log-check.log" "$OUT/monitor.sock"
        qemu-system-x86_64 "${common[@]}" -device virtio-vga -display none \
            -serial "file:$log-boot.log" -serial "file:$log-check.log" -monitor "unix:$OUT/monitor.sock,server,nowait" &
        vm=$!
        got="didn't start"
        for _ in $(seq 100); do
            sleep 3
            if grep -aq 'CI: DONE' "$log-check.log" 2>/dev/null; then
                booted="$(grep -ao 'CI: BOOTED root=[^[:space:]]*' "$log-check.log" | cut -d= -f2)"
                if [ "$booted" = "$lastroot" ]; then got=starts; else got="started $booted, not $lastroot"; fi
                break
            fi
        done
        [ "$got" = "didn't start" ] && monitor "screendump $log-stuck.ppm"
        kill "$vm" 2>/dev/null; wait "$vm" 2>/dev/null
    fi
    if [ "$got" = "$want" ]; then echo "  ok    $name $got"
    else echo "  FAIL  $name: wanted '$want', got '$got' (see $log-*)"; failed=1; fi
done <<<"$ALL"
echo "logs: $OUT"
exit "$failed"
