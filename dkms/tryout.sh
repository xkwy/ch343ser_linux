#!/bin/bash
# Temporary test drive, nothing persists across a reboot.
#
# Builds nothing: expects driver/ch343.ko to exist already (run `make` in
# driver/ first). Loads it and moves every WCH CDC interface over from cdc_acm
# so you can check the device behaves before committing to install.sh.
# Undo with revert-tryout.sh.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "run me with sudo"; exit 1; }

DKMSDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$DKMSDIR")"
KO="$REPO/driver/ch343.ko"

[ -f "$KO" ] || { echo "$KO not found -- run 'make' in driver/ first"; exit 1; }
lsmod | grep -q '^ch343 ' || insmod "$KO"

for link in /sys/bus/usb/drivers/cdc_acm/*:*; do
    [ -e "$link" ] || continue
    intf="$(basename "$link")"
    usbdev="${intf%%:*}"
    vid="$(cat "/sys/bus/usb/devices/$usbdev/idVendor" 2>/dev/null || true)"
    [ "$vid" = "1a86" ] || continue
    echo "moving $intf: cdc_acm -> usb_ch343"
    echo "$intf" > /sys/bus/usb/drivers/cdc_acm/unbind  || true
    echo "$intf" > /sys/bus/usb/drivers/usb_ch343/bind  || true
done

sleep 1
ls -l /dev/ttyCH343USB* 2>/dev/null || echo "(none -- check dmesg)"
