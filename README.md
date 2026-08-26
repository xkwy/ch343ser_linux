# ch343 linux serial driver
## Description

USB to UART(s) chip CH342/CH343/CH344/CH346/CH347/CH9101/CH9102/CH9103/CH9104/CH9105/CH9111/CH9114/CH9433 are fully compliant to the  Communications Device Class (CDC) standard(Except CH9433), they will work with a standard CDC-ACM driver (CDC - Abstract Control Model). Linux operating systems supply a default CDC-ACM driver that can be used with these USB UART devices. In Linux, this driver file name is cdc-acm.

The CDC-ACM driver has limited capabilities to control specific devices. This generic driver does not have any knowledge about specific device protocols. Because of this, device manufacturers can create an alternate, or custom driver that is capable of accessing the device specific function sets, such as hardware flow control or GPIO functions.

If you use this VCP driver, please check that the CDC-ACM driver was not installed for the USB UART devices mentioned above. You can use command "ls /dev/ttyACM*" to confirm that, to remove the CDC-ACM driver, use command "rmmod cdc-acm".

This driver supports USB to single serial port chip CH343/CH346/CH347/CH9101/CH9102/CH9111/CH9433, USB to dual serial ports chip CH342/CH346/CH347/CH9103, USB to quad serial ports chip CH344, CH9104, CH9105, CH9114, etc.

1. Open "Terminal"
2. Switch to "driver" directory
3. Compile the driver using "make", you will see the module "ch343.ko" if successful
4. Type "sudo make load" or "sudo insmod ch343.ko" to load the driver dynamically
5. Type "sudo make unload" or "sudo rmmod ch343.ko" to unload the driver
6. Type "sudo make install" to make the driver work permanently
7. Type "sudo make uninstall" to remove the driver
8. You can refer to the link below to acquire uart application, you can use gcc or Cross-compile with cross-gcc
   https://github.com/WCHSoftGroup/tty_uart

Before the driver works, you should make sure that the usb device has been plugged in and is working properly, you can use shell command "lsusb" or "dmesg" to confirm that, USB VID of these devices are [1a86], you can view all IDs from the id table which defined in "ch343.c".

If the device works well, the driver will create tty devices named "ttyCH343USBx" in /dev directory, at the same time the driver will create "ch343_iodevx" node for chips that support GPIO signals. Operating the device in the /dev directory under Linux requires root permission by default, if users want to access the device in a non root mode, they can create udev rule file related to the device.

## Permanent installation with DKMS

`sudo make install` in `driver/` copies the module into the running kernel's
module tree only, so it stops working after the next kernel upgrade. The
`dkms/` directory installs the driver through DKMS instead, which rebuilds it
automatically whenever a new kernel is installed.

```
sudo ./dkms/install.sh      # DKMS + udev rules + take over plugged-in devices
sudo ./dkms/uninstall.sh    # revert everything back to cdc_acm
```

`install.sh` does four things:

- stages `driver/ch343.[ch]` into `/usr/src/ch343-<version>/` along with
  `dkms/dkms.conf`, then builds and installs the module for every kernel that
  has headers present
- writes `/etc/modules-load.d/ch343.conf` so the module loads at boot
- installs `udev/99-ch34x.rules` (hands WCH devices over from `cdc_acm`) and
  `udev/61-ch343-serial-symlinks.rules` (stable device names)
- unbinds any WCH interface currently held by `cdc_acm` and binds it to
  `usb_ch343`, so there is no need to replug the device

Do not combine this with `make install` from `driver/`: the copy that leaves in
`/lib/modules/<kernel>/kernel/drivers/usb/serial/` competes with the one DKMS
installs. `uninstall.sh` removes both.

`dkms/Makefile` deliberately contains nothing but `obj-m := ch343.o`, because
`driver/Makefile` pins `KERNELDIR` to `uname -r` -- correct for building
against the running kernel, wrong when DKMS builds for any other one.

To try the driver before installing anything:

```
cd driver && make
sudo ../dkms/tryout.sh          # load ch343.ko, move the ports over
sudo ../dkms/revert-tryout.sh   # hand them back to cdc_acm
```

## Stable device names

The driver names its ports `/dev/ttyCH343USB0`, `ttyCH343USB1` and so on, in
probe order. Those numbers move when several adapters are plugged or unplugged,
so they cannot be used as fixed names.

The stock `/usr/lib/udev/rules.d/60-serial.rules` would normally solve this by
creating `/dev/serial/by-id/` symlinks, but it bails out early:

```
KERNEL!="ttyUSB[0-9]*|ttyACM[0-9]*", GOTO="serial_end"
```

`ttyCH343USB*` matches neither pattern, so no symlinks appear -- even though
that same file has already imported the USB properties by that point.

`udev/61-ch343-serial-symlinks.rules` redoes the second half of
`60-serial.rules` for the ch343 naming scheme, and adds short per-port aliases:

| symlink | keyed on |
| --- | --- |
| `/dev/serial/by-id/usb-<vendor>_<product>_<serial>-if<NN>` | chip serial number + USB interface |
| `/dev/serial/by-path/pci-...-usb-<port>:1.<N>` | physical USB port |
| `/dev/xkwy-<serial>-p1` .. `-p4` | chip serial number, one per UART |

The `by-id` names come out identical to the ones `cdc_acm` used to produce, so
existing scripts and terminal configs keep working across the driver switch.

The short aliases are scoped to CH344 (`1a86:55d5`). Widen the
`ENV{ID_MODEL_ID}` guard in the rule file for other chips, or add semantic
names of your own next to them:

```
ENV{ID_SERIAL_SHORT}=="88611524", ENV{ID_USB_INTERFACE_NUM}=="00", SYMLINK+="my-board-console"
```

`SYMLINK+=` accumulates, so several names can point at the same port.

## Diagnosing a laggy port

`tools/latency-check.py` drives the far end to print a numbered sequence and
reports whether the stream arrives live or runs behind:

```
tools/latency-check.py /dev/ttyCH343USB0
```

`VERDICT: LAGGING` means bytes are held in a buffer below the tty layer and
only get pushed out by later traffic. That is what a CDC-ACM device whose IN
endpoint never sends a short packet looks like: the host's read URB cannot
complete until it is filled, so the tail of every burst stays stuck and
everything the port shows is a fixed number of bytes behind. Neither
`tcflush()` nor closing and reopening the port clears it. Being able to drive
the chip's FIFO thresholds directly is the main reason to prefer this driver
over `cdc_acm` on such devices.

## Note

Any question, you can send feedback to mail: tech@wch.cn
