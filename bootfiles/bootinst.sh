#!/bin/sh
# Setup booting from disk (USB or harddrive)
# Requires: fdisk, df, tail, tr, cut, dd, sed

export PATH=.:./tools:../tools:/usr/sbin:/usr/bin:/sbin:/bin:/

# change working directory to dir from which we are started
CWD="$(pwd)"
BOOT="$(dirname "$0")"
cd "$BOOT"

# find out device and mountpoint
PART="$(df . | tail -n 1 | tr -s " " | cut -d " " -f 1)"
DEV="$(echo "$PART" | sed -r "s:[0-9]+\$::" | sed -r "s:([0-9])[a-z]+\$:\\1:i")"   #"

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then ARCH=64; else ARCH=32; fi
EXTLINUX=extlinux.x$ARCH

./"$EXTLINUX" --install "$BOOT"

if [ $? -ne 0 ]; then
   echo "Error installing boot loader."
   echo "Read the errors above and press enter to exit..."
   read junk
   exit 1
fi


if [ "$DEV" != "$PART" ]; then
   # Setup MBR on the first block
   dd bs=440 count=1 conv=notrunc if="$BOOT/mbr.bin" of="$DEV" 2>/dev/null

   # Toggle a bootable flag
   PART="$(echo "$PART" | sed -r "s:.*[^0-9]::")"
   (
      fdisk -l "$DEV" | fgrep "*" | fgrep "$DEV" | cut -d " " -f 1 \
        | sed -r "s:.*[^0-9]::" | xargs -I '{}' echo -ne "a\n{}\n"
      echo a
      echo $PART
      echo w
   ) | fdisk $DEV >/dev/null 2>&1
fi

# UEFI boot loader
mkdir -p "$BOOT/../../EFI"
mv "EFI/Boot" "$BOOT/../../EFI/"

# get $LIVEKITNAME
LIVEKITNAME="$(basename $(dirname $(pwd)))"
# change syslinux.cfg to point to the right place
sed -r "s:/$LIVEKITNAME/boot/::" "$BOOT/../../EFI/Boot/syslinux.cfg" > "$BOOT/../../EFI/Boot/syslinux.cfg.tmp" && mv "$BOOT/../../EFI/Boot/syslinux.cfg.tmp" "$BOOT/../../EFI/Boot/syslinux.cfg"

# copy the right files
cp "bootlogo.png" "initrfs.img" "vmlinuz" "$BOOT/../../EFI/Boot/"

echo "Boot installation finished."
echo "Please copy the EFI folder at the root of your Fat32 partition."
cd "$CWD"
