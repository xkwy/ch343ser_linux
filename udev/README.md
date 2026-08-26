# udev rules

Two rule files, both installed for you by `../dkms/install.sh`.

## 99-ch34x.rules

Takes WCH USB-serial devices away from the in-tree `cdc_acm` driver and binds
them to `usb_ch343` instead. Matching is per VID/PID, so other CDC-ACM devices
on the same machine keep using `cdc_acm` -- do not blacklist the module
globally.

1. Copy `99-ch34x.rules` to `/etc/udev/rules.d/`.
2. Run `sudo udevadm control -R` to reload the rules.
3. Unplug and replug the device. `cdc_acm` should no longer be used for WCH
   USB-serial converters.

## 61-ch343-serial-symlinks.rules

Creates stable names for the ports: `/dev/serial/by-id/`,
`/dev/serial/by-path/` and short `/dev/xkwy-<serial>-pN` aliases.

The stock `/usr/lib/udev/rules.d/60-serial.rules` skips `ttyCH343USB*` because
of its `KERNEL!="ttyUSB[0-9]*|ttyACM[0-9]*"` filter, so none of those symlinks
would otherwise exist. This file redoes the second half of that rule set for
the ch343 naming scheme. It must sort after `60-serial.rules`, hence the `61-`
prefix.

1. Copy `61-ch343-serial-symlinks.rules` to `/etc/udev/rules.d/`.
2. Run `sudo udevadm control -R`.
3. Run `sudo udevadm trigger --subsystem-match=tty --action=add`, or replug the
   device.

See "Stable device names" in the top-level README for what the names look like
and how to add your own.
