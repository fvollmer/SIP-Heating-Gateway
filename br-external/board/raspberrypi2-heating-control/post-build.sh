#!/bin/sh

set -u
set -e

# Add a console on tty1
if [ -e ${TARGET_DIR}/etc/inittab ]; then
    grep -qE '^tty1::' ${TARGET_DIR}/etc/inittab || \
	sed -i '/GENERIC_SERIAL/a\
tty1::respawn:/sbin/getty -L  tty1 0 vt100 # HDMI console' ${TARGET_DIR}/etc/inittab
fi

# genimage fails to create ext3 image:
# genext2fs: couldn't allocate a block (no free space)
# create it manually as suggested at:
# http://lists.busybox.net/pipermail/buildroot/2018-February/212869.html
dd if=/dev/zero of=${BINARIES_DIR}/persistent.ext3 bs=10M count=1
mkfs.ext3 -F ${BINARIES_DIR}/persistent.ext3
echo "created: ${BINARIES_DIR}/persistent.ext3"

# add fstab entry for persistent storage
mkdir -p $TARGET_DIR/media/persistent
grep -q "^/dev/mmcblk0p3" $TARGET_DIR/etc/fstab || \
    echo "/dev/mmcblk0p3	/media/persistent	ext3	rw,sync,data=journal,barrier=1,noatime,commit=1	0	2" >> \
    $TARGET_DIR/etc/fstab

# relocate asterisk database to /tmp
if [ ! -L $TARGET_DIR/usr/lib/asterisk/astdb.sqlite3 ]; then
    ln -s /tmp/astdb.sqlite3 $TARGET_DIR/usr/lib/asterisk/astdb.sqlite3
fi
