#!/bin/bash
# Remove the DKMS module and udev rules, handing the device back to cdc_acm.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "run me with sudo"; exit 1; }

DKMSDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"$/\1/p' "$DKMSDIR/dkms.conf")"

rm -f /etc/udev/rules.d/99-ch34x.rules \
      /etc/udev/rules.d/61-ch343-serial-symlinks.rules \
      /etc/modules-load.d/ch343.conf
udevadm control --reload

for link in /sys/bus/usb/drivers/usb_ch343/*:*; do
    [ -e "$link" ] || continue
    intf="$(basename "$link")"
    echo "$intf" > /sys/bus/usb/drivers/usb_ch343/unbind || true
    echo "$intf" > /sys/bus/usb/drivers/cdc_acm/bind     || true
done

rmmod ch343 2>/dev/null || true
dkms remove -m ch343 -v "$VER" --all || true
rm -rf "/usr/src/ch343-$VER"
depmod -a
echo "== reverted to cdc_acm"
ls -l /dev/ttyACM* 2>/dev/null || true
