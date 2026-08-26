#!/bin/bash
# Undo tryout.sh: give the ports back to cdc_acm and unload the module.
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "run me with sudo"; exit 1; }

for link in /sys/bus/usb/drivers/usb_ch343/*:*; do
    [ -e "$link" ] || continue
    intf="$(basename "$link")"
    echo "$intf" > /sys/bus/usb/drivers/usb_ch343/unbind || true
    echo "$intf" > /sys/bus/usb/drivers/cdc_acm/bind     || true
done
rmmod ch343 2>/dev/null || true
sleep 1
ls -l /dev/ttyACM* 2>/dev/null || true
