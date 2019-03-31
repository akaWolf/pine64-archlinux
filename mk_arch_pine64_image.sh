#!/bin/sh -eu

image="./image"
dest="./mnt"
device=""

trap error_handler 1 2 3 6 ERR

cleanup()
{
	echo "release resources"

	[[ -d "${dest}/proc" ]] && umount --quiet "${dest}/proc" || true
	[[ -d "${dest}/dev" ]] && umount --quiet --recursive "${dest}/dev" || true
	[[ -d "${dest}/sys" ]] && umount --quiet --recursive "${dest}/sys" || true
	[[ -d "${dest}/run" ]] && umount --quiet --recursive "${dest}/run" || true

	[[ -d "$dest" ]] && umount --quiet $dest || true

	[[ ! -z "$device" ]] && losetup -d $device
}

error_handler()
{
	cleanup
	exit 1
}

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

rm -f ArchLinuxARM-aarch64-latest.tar.gz

curl --progress-bar --remote-name --location https://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

echo "unpacking rootfs"

bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C $dest

echo "chrooting and configuring"

cp /usr/bin/qemu-aarch64-static "${dest}/usr/bin"

mount -t proc /proc "${dest}/proc"
mount --rbind /dev "${dest}/dev"
mount --make-rslave "${dest}/dev"
#mount -o bind /dev/pts "${dest}/dev/pts"
mount --rbind /sys "${dest}/sys"
mount --make-rslave "${dest}/sys"
mount --rbind /run "${dest}/run"
mount --make-rslave "${dest}/run"

[[ ! -f /proc/sys/fs/binfmt_misc/aarch64 ]] && echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/usr/bin/qemu-aarch64-static:' > /proc/sys/fs/binfmt_misc/register

chroot_commands="
pacman-key --init &&
pacman-key --populate archlinuxarm &&
killall -KILL gpg-agent &&
pacman -Sy --noconfirm uboot-pine64
"

chroot $dest /bin/bash -c "$chroot_commands" < /dev/null

rm "${dest}/usr/bin/qemu-aarch64-static"

echo "writing bootloader"

dd if="${dest}/boot/u-boot-sunxi-with-spl.bin" of=$image bs=8k seek=1 conv=notrunc status=noxfer

cleanup

echo "done!"
echo $(du -h $(realpath $image))

echo "credits: https://archlinuxarm.org/platforms/armv8/allwinner/pine64"
