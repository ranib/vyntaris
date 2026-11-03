#!/usr/bin/env bash
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${VM_OUT:-$REPO/tools/vm-test}"
ISO="${1:-$(ls -t "$REPO"/iso/out/*.iso 2>/dev/null | head -n1)}"
STAGE="${STAGE:-all}"
USER_NAME=tester
USER_PASS="test"
OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd
OVMF_VARS=/usr/share/edk2/x64/OVMF_VARS.4m.fd

[ -f "$ISO" ] || { echo "no ISO (build one with iso/build.sh)" >&2; exit 1; }
mkdir -p "$OUT"
kvm=(); [ -w /dev/kvm ] && kvm=(-enable-kvm -cpu host)
cpus=$(( $(nproc) - 1 )); [ "$cpus" -gt 4 ] && cpus=4; [ "$cpus" -lt 1 ] && cpus=1
renice -n 5 $$ >/dev/null 2>&1 || true
ionice -c 3 -p $$ >/dev/null 2>&1 || true
common=("${kvm[@]}" -machine q35 -m "${VM_MEM:-4096}" -smp "$cpus"
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$OUT/vars.fd"
    -drive "file=$OUT/disk.qcow2,if=virtio,format=qcow2"
    -nic user,model=virtio-net-pci)

mon() {
    python3 - "$OUT/monitor.sock" "$*" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])
s.sendall((sys.argv[2] + "\n").encode()); time.sleep(0.15); s.close()
PY
}
shot() { mon "screendump $OUT/$1.png -f png"; sleep 1; echo "   screenshot $1.png"; }
type_text() {
    local ch
    for ((i = 0; i < ${#1}; i++)); do
        ch="${1:i:1}"
        mon "sendkey $ch"
        sleep 0.08
    done
}

if [ "$STAGE" = gui ]; then
    echo ":: stage 1: graphical install from $(basename "$ISO")"
    rm -f "$OUT"/*.png "$OUT/monitor.sock" "$OUT/qmp.sock"
    qemu-img create -q -f qcow2 "$OUT/disk.qcow2" 24G
    cp "$OVMF_VARS" "$OUT/vars.fd"
    qemu-system-x86_64 "${common[@]}" -machine vmport=off -cdrom "$ISO" -boot d \
        -device virtio-vga -device qemu-xhci -device usb-tablet -display none \
        -monitor "unix:$OUT/monitor.sock,server,nowait" -qmp "unix:$OUT/qmp.sock,server,nowait" &
    vm=$!
    trap 'kill $vm 2>/dev/null || true' EXIT
    until [ -S "$OUT/qmp.sock" ]; do sleep 0.5; done
    drive() { (cd "$OUT" && python3 "$REPO/tools/vm-drive.py" "$@"); }
    next() { drive click 997 652; sleep 2; }
    sleep 8;  mon "sendkey ret"
    sleep 100; shot gui-1-welcome
    next; shot gui-2-internet
    next; shot gui-3-keyboard
    next; shot gui-4-timezone
    next
    drive click 710 304; drive type "Tester"
    drive click 710 454; drive type "$USER_PASS"
    drive click 710 498; drive type "$USER_PASS"
    sleep 1; shot gui-5-you
    next
    shot gui-6-disk
    next; shot gui-7-summary
    drive click 1000 652
    sleep 120; shot gui-8-installing
    for ((t = 0; t < 90; t++)); do
        sleep 60
        drive shot "$OUT/now.png"
        c="$(magick "$OUT/now.png" -format '%[fx:int(255*p{1010,652}.r)] %[fx:int(255*p{1010,652}.b)]' info:)"
        read -r r b <<<"$c"
        [ "$r" -gt 170 ] && [ "$b" -gt 200 ] && break
        [ $((t % 10)) = 9 ] && cp "$OUT/now.png" "$OUT/gui-8-installing-$t.png"
    done
    shot gui-9-done
    kill $vm 2>/dev/null || true; wait $vm 2>/dev/null || true
    [ "$t" -lt 90 ] || { echo "the installation did not finish, see $OUT/gui-9-done.png" >&2; exit 1; }
    echo "   installed"
    STAGE=boot
fi

if [ "$STAGE" = all ]; then
    echo ":: stage 1: install from $(basename "$ISO")"
    rm -f "$OUT"/*.png "$OUT/install.log"
    qemu-img create -q -f qcow2 "$OUT/disk.qcow2" "$([ -n "${VM_DUAL:-}" ] && echo 48G || echo 24G)"
    cp "$OVMF_VARS" "$OUT/vars.fd"

    rm -rf "${OUT:?}/boot"; mkdir -p "$OUT/boot"
    bsdtar -xf "$ISO" -C "$OUT/boot" arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img
    options="$(bsdtar -xOf "$ISO" loader/entries/01-archiso-linux.conf | sed -n 's/^options *//p')"

    rm -rf "$OUT/current" "$OUT/current.tar.gz" && mkdir -p "$OUT/current"
    if [ -z "${ISO_ONLY:-}" ]; then
        "$REPO/tools/package.sh" >/dev/null
        cp "$(ls -t "$REPO"/pkg/vyntaris-*.pkg.tar.zst | head -n1)" "$(ls -t "$REPO"/pkg/yay-bin-*.pkg.tar.zst | head -n1)" \
            "$REPO/iso/airootfs/usr/local/bin/install-desktop" \
            "$REPO/packages.txt" "$REPO/iso/base-packages" "$OUT/current/"
        tar -C "$OUT/current" -czf "$OUT/current.tar.gz" .
    fi

    cp "$REPO/tools/vm-check.sh" "$OUT/vm-check.sh"
    cat > "$OUT/auto.sh" <<EOF
#!/bin/bash
exec > >(tee /dev/ttyS0) 2>&1
if curl -fsSo /tmp/current.tar.gz http://10.0.2.2:8123/current.tar.gz; then
    mkdir -p /tmp/current && tar -C /tmp/current -xzf /tmp/current.tar.gz
    rm -f /opt/vyntaris-repo/*.pkg.tar.* && cp /tmp/current/*.pkg.tar.zst /opt/vyntaris-repo/
    repo-add -q -R /opt/vyntaris-repo/vyntaris.db.tar.gz /opt/vyntaris-repo/*.pkg.tar.zst
    install -m755 /tmp/current/install-desktop /usr/local/bin/install-desktop
    install -m644 /tmp/current/packages.txt /tmp/current/base-packages /usr/share/desktop-installer/
    echo "using the package and installer from the host's tree"
fi
if [ -n "${VM_OFFLINE:-}" ]; then
    ip route add unreachable default metric 1
    if curl -fsI --max-time 8 https://archlinux.org >/dev/null 2>&1; then echo "the internet is still reachable"; echo "INSTALL-RESULT=9"; poweroff; fi
    echo "no internet from here on (only the host's test files)"
fi
mode=erase
if [ -n "${VM_DUAL:-}" ]; then
    sgdisk -Z /dev/vda >/dev/null
    sgdisk -n 1:0:+300M -t 1:ef00 -c 1:EFI -n 2:0:+6G -t 2:8300 -c 2:other /dev/vda >/dev/null
    partprobe /dev/vda; udevadm settle
    mkfs.fat -F 32 /dev/vda1 >/dev/null; mkfs.ext4 -qF -L other /dev/vda2
    mount /dev/vda1 /mnt && mkdir -p /mnt/EFI/Microsoft/Boot && cp /usr/share/edk2-shell/x64/Shell_Full.efi /mnt/EFI/Microsoft/Boot/bootmgfw.efi && umount /mnt
    mount /dev/vda2 /mnt && echo "the other system's" > /mnt/marker && umount /mnt
    mode=free
    echo "dual boot: another system on /dev/vda1-2, Vyntaris into the free space"
fi
INSTALL_MODE=\$mode \\
INSTALL_DISK=/dev/vda INSTALL_USER=$USER_NAME INSTALL_PASSWORD=$USER_PASS INSTALL_HOSTNAME=vmtest \\
INSTALL_TIMEZONE=Europe/Belgrade INSTALL_KEYMAP=us INSTALL_LOCALE=en_US.UTF-8 INSTALL_YES=1 \\
    install-desktop
result=\$?
if [ "\$result" = 0 ]; then
    root="\$(lsblk -lnpo NAME,PARTTYPE /dev/vda | awk 'tolower(\$2) == "4f68bce3-e8cd-4db1-96e7-fbcaf984b709" {print \$1}')"
    opts=""; [ "\$(lsblk -no FSTYPE "\$root")" = btrfs ] && opts="-o subvol=@"
    if mount \$opts "\$root" /mnt \\
        && curl -fsSo /mnt/usr/local/bin/vyntaris-vm-check http://10.0.2.2:8123/vm-check.sh \\
        && chmod 755 /mnt/usr/local/bin/vyntaris-vm-check \\
        && printf '[Unit]\\nDescription=Vyntaris VM test check\\nAfter=multi-user.target\\n[Service]\\nType=simple\\nExecStart=/usr/local/bin/vyntaris-vm-check $USER_NAME ${VM_DUAL:+dual}\\n[Install]\\nWantedBy=multi-user.target\\n' \\
            > /mnt/etc/systemd/system/vyntaris-vm-check.service \\
        && ln -sf /etc/systemd/system/vyntaris-vm-check.service /mnt/etc/systemd/system/multi-user.target.wants/; then
        umount /mnt
    else
        echo "the VM check couldn't be put into the installed system (root: \${root:-not found})"
        result=1
    fi
fi
echo "INSTALL-RESULT=\$result"
sleep 2
poweroff
EOF
    (cd "$OUT" && exec python3 -m http.server 8123 --bind 127.0.0.1 >/dev/null 2>&1) &
    http=$!
    trap 'kill $http 2>/dev/null || true' EXIT

    for attempt in 1 2; do
        timeout 20m qemu-system-x86_64 "${common[@]}" \
            -cdrom "$ISO" \
            -kernel "$OUT/boot/arch/boot/x86_64/vmlinuz-linux" \
            -initrd "$OUT/boot/arch/boot/x86_64/initramfs-linux.img" \
            -append "$options console=tty0 console=ttyS0,115200 script=http://10.0.2.2:8123/auto.sh" \
            -display none -serial "file:$OUT/install.log" -monitor none || true
        grep -aq 'INSTALL-RESULT=' "$OUT/install.log" && break
        [ "$attempt" = 2 ] && break
        echo "   the install VM stopped answering (last: $(tail -n1 "$OUT/install.log" | tr -d '\r'); free on the host: $(df -h --output=avail "$OUT" | tail -n1 | tr -d ' ')): once more"
        cp "$OUT/install.log" "$OUT/install-frozen.log"
        qemu-img create -q -f qcow2 "$OUT/disk.qcow2" "$([ -n "${VM_DUAL:-}" ] && echo 48G || echo 24G)"
        cp "$OVMF_VARS" "$OUT/vars.fd"
    done
    kill $http 2>/dev/null || true
    result="$(grep -ao 'INSTALL-RESULT=[0-9]*' "$OUT/install.log" | tail -n1)"
    echo "   $result"
    [ "$result" = "INSTALL-RESULT=0" ] || { echo "install failed, see $OUT/install.log" >&2; exit 1; }
    if [ -n "${VM_OFFLINE:-}" ]; then
        grep -aq 'installing from this USB' "$OUT/install.log" || { echo "it didn't install from the ISO's own packages" >&2; exit 1; }
        echo "   installed without internet"
    fi
fi

boot_check() {
    local round="$1"
    echo ":: $round: boot the installed system, log in, check it"
    rm -f "$OUT/monitor.sock" "$OUT/boot.log" "$OUT/check.log"
    qemu-system-x86_64 "${common[@]}" \
        -device virtio-vga -display none -serial "file:$OUT/boot.log" -serial "file:$OUT/check.log" \
        -monitor "unix:$OUT/monitor.sock,server,nowait" &
    vm=$!
    trap 'kill $vm 2>/dev/null || true' EXIT
    until [ -S "$OUT/monitor.sock" ]; do sleep 0.5; done

    sleep 6;  shot "$round-1-boot"
    sleep 14; shot "$round-2-splash"
    if wait_seen "CI: READY-FOR-LOGIN" 900; then
        shot "$round-3-login"
        type_text "$USER_PASS"; mon "sendkey ret"
        sleep 30; shot "$round-4-desktop"
        wait_seen "CI: CHECK-RESULT=" 600 || true
        shot "$round-5-desktop-later"
        mon "sendkey meta_l"; sleep 3; shot "$round-6-start-menu"
        mon "sendkey esc"; sleep 1
        mon "sendkey meta_l-l"; sleep 4; shot "$round-7-locked"
        type_text "$USER_PASS"; mon "sendkey ret"; sleep 4; shot "$round-8-unlocked"
    fi
    mon "system_powerdown"
    for ((w = 0; w < 60; w++)); do kill -0 $vm 2>/dev/null || break; sleep 1; done
    kill $vm 2>/dev/null || true; wait $vm 2>/dev/null || true

    echo ":: what the installed system reported"
    grep -a "^CI:" "$OUT/check.log" | sed 's/^CI: /   /' || true
    cp "$OUT/check.log" "$OUT/$round-check.log"; cp "$OUT/boot.log" "$OUT/$round-boot.log"
    seen "CI: CHECK-RESULT=ok" || { echo "the installed system didn't check out (see above, $OUT/$round-check.log)" >&2; exit 1; }
}
seen() { grep -aq "$1" "$OUT/check.log" 2>/dev/null; }
wait_seen() {
    for ((w = 0; w < $2; w += 2)); do seen "$1" && return 0; kill -0 $vm 2>/dev/null || return 1; sleep 2; done
    return 1
}

boot_check stage2

if [ -n "${options:-}" ] && [ -z "${VM_NO_REPAIR:-}" ]; then
    echo ":: stage 3: repair it from the USB (repair-desktop)"
    cat > "$OUT/repair.sh" <<'REPAIR'
#!/bin/bash
exec > >(tee /dev/ttyS0) 2>&1
dev="$(repair-desktop list | awk -F'\t' 'NR == 1 {print $1}')"
echo "found: ${dev:-nothing}"
[ -n "$dev" ] && repair-desktop snapshots "$dev" && repair-desktop boot "$dev"
echo "REPAIR-RESULT=$?"
sleep 2
poweroff
REPAIR
    (cd "$OUT" && exec python3 -m http.server 8123 --bind 127.0.0.1 >/dev/null 2>&1) &
    http=$!
    timeout 20m qemu-system-x86_64 "${common[@]}" \
        -cdrom "$ISO" \
        -kernel "$OUT/boot/arch/boot/x86_64/vmlinuz-linux" \
        -initrd "$OUT/boot/arch/boot/x86_64/initramfs-linux.img" \
        -append "$options console=tty0 console=ttyS0,115200 script=http://10.0.2.2:8123/repair.sh" \
        -display none -serial "file:$OUT/repair.log" -monitor none || true
    kill $http 2>/dev/null || true
    grep -a "^found:\|^::\|^error" "$OUT/repair.log" | sed 's/^/   /' || true
    result="$(grep -ao 'REPAIR-RESULT=[0-9]*' "$OUT/repair.log" | tail -n1)"
    echo "   $result"
    [ "$result" = "REPAIR-RESULT=0" ] || { echo "the repair failed, see $OUT/repair.log" >&2; exit 1; }
    boot_check stage4
fi
if [ -z "${VM_DUAL:-}" ] && [ -z "${VM_NO_ROLLBACK:-}" ]; then
    echo ":: stage 5: a bad update undoes itself"
    rm -f "$OUT/check.log"
    timeout 15m qemu-system-x86_64 "${common[@]}" -no-reboot -fw_cfg name=opt/vyntaris/action,string=bad-update \
        -display none -serial "file:$OUT/boot.log" -serial "file:$OUT/check.log" -monitor none || true
    grep -a "^CI:" "$OUT/check.log" | sed 's/^CI: /   /' || true
    cp "$OUT/check.log" "$OUT/stage5-bad-update.log"
    seen "CI: BAD-UPDATE-DONE" || { echo "the bad update wasn't made" >&2; exit 1; }
    entry=""
    for ((try = 1; try <= 5; try++)); do
        rm -f "$OUT/check.log"
        qemu-system-x86_64 "${common[@]}" -display none -serial "file:$OUT/boot.log" -serial "file:$OUT/check.log" -monitor none &
        vm=$!
        wait_seen "CI: ENTRY=" 600 || true
        entry="$(grep -ao 'CI: ENTRY=.*' "$OUT/check.log" | head -n1 | sed 's/^CI: ENTRY=//')"
        echo "   start $try: ${entry:-nothing}"
        if [[ "$entry" == vyntaris-rollback* ]]; then
            wait_seen "CI: READY-FOR-LOGIN" 600 || true
            kill $vm 2>/dev/null || true; wait $vm 2>/dev/null || true
            cp "$OUT/check.log" "$OUT/stage5-rollback.log"
            break
        fi
        sleep 40
        kill $vm 2>/dev/null || true; wait $vm 2>/dev/null || true
    done
    grep -a "^CI:" "$OUT/check.log" | sed 's/^CI: /   /' || true
    [[ "$entry" == vyntaris-rollback* ]] || { echo "the update never undid itself" >&2; exit 1; }
    seen "CI: ROLLED-BACK" || { echo "the start from the entry back didn't roll back" >&2; exit 1; }
    seen "CI: FAIL" && { echo "the rolled-back system didn't check out" >&2; exit 1; }
    boot_check stage6
    grep -aq "CI: ENTRY=vyntaris.efi" "$OUT/check.log" || { echo "after the rollback, the next start isn't from vyntaris.efi" >&2; exit 1; }
fi
echo "   screenshots and logs in $OUT"
echo ":: VM-TEST-RESULT=ok"
