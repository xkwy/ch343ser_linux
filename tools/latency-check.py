#!/usr/bin/env python3
"""Measure how far behind a serial port's RX stream runs.

Drives the far end to print LINE1..LINE200, then checks which numbers actually
arrive. A healthy port sees the whole run end-to-end; a port whose IN endpoint
never sends short packets stops partway and only catches up when new traffic
pushes the tail out.

usage: latency-check.py /dev/ttyCH343USB0
"""
import os, sys, re, time, select, termios

def openraw(path):
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    a = termios.tcgetattr(fd)
    a[0] = a[1] = a[3] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    a[4] = a[5] = termios.B115200
    a[6][termios.VMIN] = 0
    a[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, a)
    return fd

def read_until_quiet(fd, quiet=3.0, maxt=25):
    t0 = last = time.time(); total = 0
    while time.time() - t0 < maxt:
        if select.select([fd], [], [], 0.2)[0]:
            try:
                d = os.read(fd, 65536)
                if d:
                    total += len(d); last = time.time()
            except BlockingIOError:
                pass
        if time.time() - last > quiet:
            break
    return total

def main(path):
    fd = openraw(path)
    stale = read_until_quiet(fd)
    termios.tcflush(fd, termios.TCIOFLUSH)
    os.write(fd, b"i=1; while [ $i -le 200 ]; do echo LINE$i; i=$((i+1)); done; echo DONEMARK\r")
    t0 = time.time(); buf = b''
    while time.time() - t0 < 15:
        if select.select([fd], [], [], 0.2)[0]:
            try:
                d = os.read(fd, 65536)
                if d:
                    buf += d
            except BlockingIOError:
                pass
    nums = [int(x) for x in re.findall(rb'LINE(\d+)', buf)]
    print('port           : %s' % path)
    print('stale drained  : %d B' % stale)
    print('rx             : %d B, %d LINEs' % (len(buf), len(nums)))
    if nums:
        print('first / last   : LINE%d / LINE%d' % (nums[0], nums[-1]))
        jumps = [(nums[i], nums[i+1]) for i in range(len(nums)-1)
                 if nums[i+1] != nums[i] + 1]
        print('discontinuities: %s' % (jumps[:6] or 'none'))
        if nums[-1] == 200 and not jumps:
            print('VERDICT        : OK, stream is live (reached LINE200 in order)')
        else:
            stuck = 200 - nums[-1]
            print('VERDICT        : LAGGING, tail LINE%d..LINE200 (~%d B) still held'
                  % (nums[-1] + 1, stuck * 9))
    else:
        print('VERDICT        : no LINEs at all -- far end printed nothing, or the '
              'whole run is still held in the buffer')
    os.close(fd)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '/dev/ttyCH343USB0')
