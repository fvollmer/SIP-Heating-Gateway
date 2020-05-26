SIP Heating Gateway
====================

This device allows you to control the heating (or any other device) by calling in and using an interactive voice menu. In case of a power loss the last state will be restored as soon as the power is back. The software is build to survive unexpected power losses.

## Usage

Connect Power (5V via micro-USB and 12V), ethernet and the output to the relay. After bootup (about 10s) the device accepts incoming calls.

Call the device,  wait until pickup and follow the voice instructions:
1. Enter the PIN and press `#`
2. Press `1` to turn the heating on, `2` to turn the heating off, `3` to get the status of the heating
3. Repeat step 2, or hang up

After a timeout the caller will be disconnected automatically.

```
                                               5V (micro USB)
                                                |
                                                v
+-----------------+                      +----------------+              +----------+
| router / switch | SIP (over ethernet)  | Raspberry Pi   | 12V Switched | Relay of |
| e.g. fritzbox   |<-------------------->| (with 12V hat) |------------->| heating  |
+-----------------+                      +----------------+              +----------+
                                                ^
                                                |
                                              12 V
```

## Configuration
The custom embedded system is based on buildroot. The behaviour at a call is controlled by [Asterisk](https://www.asterisk.org/). There are two main configuration files:
 * `/etc/asterisk/sip.conf`
   SIP server configuration
 * `/etc/asterisk/extensions.conf`
   Dialplan (phone menu, pin)

The configuration files can be adjusted by changing the files at the overlay (`br-external/board/raspberrypi2-heating-control/rootfs-overlay`.

It is also possible to connect to the device via a serial connection (115200 8N1) or HDMI (untested). The system is by default read-only. To modify the file system it has to be remounted (`mount -o remount,rw /`). The login data is:

username: "root"
password: ""
(There is no root password. This is no problem, since there is no way to login remotely)

## Working principle
This device is based on a raspberry pi. The raspberry pi connects via ethernet to the a SIP server (e.g. a fritzbox router or your isp). The SIP connection and the voice menu is handled by the software asterisk, which is installed on the raspberry pi.

The raspberry pi is configured to use the micro sd card as read only storage. This should prevent damage on power failure. The only exception is a persitent partition, which is used to save the current state. This state will be restored in case of a power failure. This partition should also be safe from corruption due to the mount parametera and the infrequent writes.

The GPIO Pins of the raspberry pi are used to switch a relay, that controls the heating. The switching voltage is provided by an external power supply. A BJT provides an open collector output. This circuit is realized on a custom pcb (hat). The GPIO Pin 17 controls the BJT. The relay is connected to the open collector output and the 12V rail.

## How to build the sd card image
1. Clone repository (use `--recursive` to get buildroot submodule)
2. Change into software folder (`cd software`)
3. `make BR2_EXTERNAL=$PWD/br-external -C buildroot raspberrypi2-heating-control_defconfig`
4. `make -C buildroot`
5. write `buildroot/output/images/sdcard.img` to sd card (e.g. `dd if=buildroot/output/images/sdcard.img of=/dev/mmcblk0 bs=1M && sync`)

## Hardware
TBD

## Good to know
 * This system uses [Buildroot](https://buildroot.org/) to create a custom embedded system. This provides more flexibility and allows more customization than a stripped down raspbian. The complete image is just a little bigger than 100MB.
 * Connect via 3.3V serial (115200 8N1)
   There should also be a console on the HDMI port (untested).
 * The heating can be controlled by with `/opt/heatingControl/controlheating`
 * The root system is read only. It can be mounted as rw (`mount / -o remount,rw`), but this is only recommand for testing. Every change should be integrated into `br-external`
 * There is a small persistent storage partition at the sd card. It is mounted at boot via fstab at `/media/persistent/`. The mount options `rw,sync,data=journal,barrier=1,noatime,commit=1` were choosen to avoid data corruption and wear of the sd card. It is only used to store store the current state at `/media/persistent/last_state` and to restore it after a power loss. On every boot `/etc/init.d/S10restorestate` tries to restore the last state. 
 * To debug problems it might be useful to connect to a running asterisk in verbose mode: `sudo asterisk -rvvvv`
 * Any file can be added/overwritten by adding it ot the rootfs overlay at `br-external/board/raspberrypi2-heating-control/rootfs-overlay/`. 
 * The asterisk configuration files can be found at `/etc/asterisk`. The build process automatically deploys the default configuration files. The overlay is used to overwrite them.
    - SIP configuration file: `/etc/asterisk/sip.conf`
    - Dialplan (phone menu, pin): `/etc/asterisk/extensions.conf`
 * The configuration is based on the raspberry pi 2 configuration. It should be easily adjusted to newer versions. It probably even boots, but the serial console is most likely broken, due to a hardware difference.
 * The dhcp client was configured to run in the background. This is useful if the network link isn't ready when we try to get an ip address. This archived with a custom busybox configuration with the option `CONFIG_IFUPDOWN_UDHCPC_CMD_OPTIONS=-R -b -O search"`. The option `-b` sets udhcpc to run in the background. (`-R` is release on exit, `-O search` enables domain search option RFC 3397)

## Overview of files
```
├──audio-gen
│  └── <infos about the audio file generation>
├──buildroot
└──br-external
   ├── board
   │   └── raspberrypi2-heating-control
   │       ├── genimage-raspberrypi2-heating-control.cfg
   │       ├── post-build.sh
   │       ├── post-image.sh
   │       └── rootfs-overlay
   │           └── <config files and scripts>
   ├── Config.in
   ├── configs
   │   └── raspberrypi2-heating-control_defconfig
   ├── external.desc
   └── external.mk
```

## Enhancement Ideas

 * Don't run asterisk as root. This sounds simple in theory, but the user needs permissions to write to /sys/class/gpio. The best way to archive this is probably to use `mdev` together with the `devtmpfs`.
 * The logs could potentially fill up our tmpfs. The best way to avoid this would be `logrotate`. For now asterisk is running with disabled logging and cdr. You can still connect to asterisk (`asterisk -r`) and take a look at the events.
