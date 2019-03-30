#!/bin/sh -eu

image="./image"
dest="./mnt"

cd /tmp

echo "deleting $image and $dest"

rm -rf $image $dest

echo "writing empty image with zeroes"

dd if=/dev/zero of=$image bs=1M count=2048 status=noxfer

echo "writing partition table"

echo '4096,,83;' | sfdisk --quiet $image

echo "creating loop device"

device=$(losetup --partscan --show --find $image)

echo "device is $device"

partition="${device}p1"

echo "formatting $partition as ext4"

mkfs.ext4 -q $partition

mkdir $dest

echo "mounting $partition to $dest"

mount $partition $dest

echo "downloading rootfs"

rm -rf ArchLinuxARM-aarch64-latest.tar.gz

curl --silent --remote-name --location http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

echo "unpacking rootfs"

bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C $dest

echo "downloading and copying boot script"

curl --silent --output "${dest}/boot/boot.scr" http://os.archlinuxarm.org/os/allwinner/boot/pine64/boot.scr

echo "release resources"

umount $dest

losetup -d $device

echo "downloading bootloader"

rm -rf u-boot-sunxi-with-spl.bin

curl --silent --remote-name --location http://os.archlinuxarm.org/os/allwinner/boot/pine64/u-boot-sunxi-with-spl.bin

echo "writing bootloader"

dd if=u-boot-sunxi-with-spl.bin of=$image bs=8k seek=1 conv=notrunc status=noxfer

echo "done!"
echo $(ls -l $image)

echo "you need to do after boot:"
echo "pacman-key --init"
echo "pacman-key --populate archlinuxarm"
echo "rm /boot/boot.scr"
echo "pacman -Sy uboot-pine64"
echo "credits: https://archlinuxarm.org/platforms/armv8/allwinner/pine64"
