#!/bin/bash
# Install ch343 permanently: DKMS (survives kernel upgrades) + udev rules that
# take the device away from cdc_acm and give every port a stable name.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "run me with sudo"; exit 1; }

DKMSDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$DKMSDIR")"
VER="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"$/\1/p' "$DKMSDIR/dkms.conf")"
DST="/usr/src/ch343-$VER"

command -v dkms >/dev/null || { echo "dkms not installed: apt install dkms"; exit 1; }

echo "== 1. stage source into $DST"
rm -rf "$DST"; install -d "$DST"
install -m644 "$REPO/driver/ch343.c" "$REPO/driver/ch343.h" "$DST/"
install -m644 "$DKMSDIR/dkms.conf" "$DKMSDIR/Makefile" "$DST/"

echo "== 2. register with DKMS and build for every installed kernel"
dkms remove -m ch343 -v "$VER" --all >/dev/null 2>&1 || true
dkms add -m ch343 -v "$VER"
built=0
for build in /lib/modules/*/build; do
    [ -e "$build" ] || continue
    kver="$(basename "$(dirname "$build")")"
    echo "   -> $kver"
    dkms build   -m ch343 -v "$VER" -k "$kver"
    dkms install -m ch343 -v "$VER" -k "$kver" --force
    built=$((built + 1))
done
[ "$built" -gt 0 ] || { echo "no kernel headers found: apt install linux-headers-\$(uname -r)"; exit 1; }

echo "== 3. load the module at boot"
printf 'ch343\n' > /etc/modules-load.d/ch343.conf

echo "== 4. install udev rules"
install -m644 "$REPO/udev/99-ch34x.rules"                  /etc/udev/rules.d/
install -m644 "$REPO/udev/61-ch343-serial-symlinks.rules"  /etc/udev/rules.d/
udevadm control --reload

echo "== 5. take over devices that are already plugged in"
modprobe ch343
for link in /sys/bus/usb/drivers/cdc_acm/*:*; do
    [ -e "$link" ] || continue
    intf="$(basename "$link")"
    usbdev="${intf%%:*}"
    vid="$(cat "/sys/bus/usb/devices/$usbdev/idVendor" 2>/dev/null || true)"
    [ "$vid" = "1a86" ] || continue
    echo "   moving $intf: cdc_acm -> usb_ch343"
    echo "$intf" > /sys/bus/usb/drivers/cdc_acm/unbind  || true
    echo "$intf" > /sys/bus/usb/drivers/usb_ch343/bind  || true
done
udevadm trigger --subsystem-match=tty --action=add

echo "== done"
dkms status | grep ch343 || true
ls -l /dev/ttyCH343USB* 2>/dev/null || echo "(no ttyCH343USB* yet -- check dmesg)"
echo "-- /dev/serial/by-id --"; ls -l /dev/serial/by-id/ 2>/dev/null | grep -i ch343 || true
