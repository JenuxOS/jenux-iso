#!/bin/bash
umask 022
set -u
if lsmod|grep -qw nbd;then
sleep .01
else
echo attempting to load nbd module to create vm disks
if modprobe nbd;then
sleep .01
else
echo cannot load nbd module
exit 48
fi
fi
iso_name=Jenux
iso_label="JENUX_$(date +%Y)"
iso_version=$(date +%Y.%m.%d)
install_dir=arch
work_dir=work
out_dir=out
arch=$(uname -m)
verbose="-v"
script_path=$(readlink -f ${0%/*})
_usage ()
{
    echo "usage ${0} [options]"
    echo
    echo " General options:"
    echo "    -N <iso_name>      Set an iso filename (prefix)"
    echo "                        Default: ${iso_name}"
    echo "    -V <iso_version>   Set an iso version (in filename)"
    echo "                        Default: ${iso_version}"
    echo "    -L <iso_label>     Set an iso label (disk label)"
    echo "                        Default: ${iso_label}"
    echo "    -D <install_dir>   Set an install_dir (directory inside iso)"
    echo "                        Default: ${install_dir}"
    echo "    -w <work_dir>      Set the working directory"
    echo "                        Default: ${work_dir}"
    echo "    -o <out_dir>       Set the output directory"
    echo "                        Default: ${out_dir}"
    echo "    -v                 Enable verbose output"
    echo "    -h                 This help message"
    exit ${1}
}
run_once() {
    if [[ ! -e ${work_dir}/build.${1}_${arch} ]]; then
        $1
        touch ${work_dir}/build.${1}_${arch}
    fi
}
make_pacman_conf() {
for d in "${work_dir}/${arch}" "${work_dir}/${arch}/airootfs" "${work_dir}/iso/${install_dir}";do
if [ -d $d ];then
sleep .01
else
mkdir -p $d
fi
done
local _cache_dirs
    _cache_dirs=($(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g'))
    if [ $arch = "aarch64" ];then
    curl -s -Lo ${script_path}/pacman.${arch}.conf https://nashcentral.duckdns.org/autobuildres/pi/pacman.$arch.conf
mkdir -p "${work_dir}/${arch}/airootfs/etc/pacman.d"
export prepkgdir=$PWD
cd "${work_dir}/${arch}/airootfs"
while true;do
export keyringurl=`lynx --dump -listonly -nonumbers os.archlinuxarm.org/$arch/core|grep archlinuxarm-keyring|grep .tar|sed "/.sig/d"|tail -n 1|cut -f 4 -d \  `
if curl -LO $keyringurl;then
break
else
continue
fi
done
while true;do
export mirrorlisturl=`lynx --dump -listonly os.archlinuxarm.org/$arch/core|grep pacman-mirrorlist|grep .tar|sed "/.sig/d"|tail -n 1|cut -f 3 -d \  `
if curl -Lo mirrors.tar $mirrorlisturl;then
break
else
continue
fi
done
pacman --needed --noconfirm -U *.pkg*
tar -xf mirrors.tar etc/pacman.d/mirrorlist
sed -i "s|\# Server|Server|g" etc/pacman.d/mirrorlist
rm *.pkg* mirrors.tar
cd $prepkgdir
else
curl -Lo ${script_path}/pacman.${arch}.conf https://nashcentral.duckdns.org/autobuildres/linux/pacman.${arch}.conf
fi
sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n ${_cache_dirs[@]})|g" ${script_path}/pacman.$arch.conf > ${work_dir}/pacman.${arch}.conf
if [ $arch = "aarch64" ];then
sed -i "s|Include = \/etc\/pacman.d\/mirrorlist|Include = ${work_dir}\/${arch}\/airootfs\/etc\/pacman.d\/mirrorlist|g" "${work_dir}/pacman.${arch}.conf"
fi
if [ $arch = "i686" ];then
mkdir -p "${work_dir}/${arch}/airootfs/etc/pacman.d"
curl -sL https://git.archlinux32.org/packages/plain/core/pacman-mirrorlist/mirrorlist|sed "s|#Server|Server|g" > "${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist"
sed -i "s|Include = \/etc\/pacman.d\/mirrorlist|Include = ${work_dir}\/${arch}\/airootfs\/etc\/pacman.d\/mirrorlist|g" "${work_dir}/pacman.${arch}.conf"
fi
mkdir -p ${work_dir}/${arch}/airootfs/var/lib/pacman/
export preset="base"
curl -s https://nashcentral.duckdns.org/autobuildres/linux/pkg.${preset}|tr \  \\n|sed "/pacstrap/d;/\/mnt/d;/--overwrite/d;/\\\\\*/d" > packages.${arch}
if [ $arch = "aarch64" ];then
sed -i "/qemu-system-arm/d;/qemu-system-x86/d" packages.${arch}
fi
if [ $arch = "i686" ];then
sed -i "/qemu-img/d;s|zfs-dkms||g;s|qemu-base|qemu-headless|g" packages.${arch}
fi
echo -n pacman --config ${work_dir}/pacman.${arch}.conf -r ${work_dir}/${arch}/airootfs -Syyp\   > installtest.${arch}
cat packages.${arch}|tr \\n \  >> installtest.${arch}
chmod 700 installtest.${arch}
for f in `./installtest.${arch} 2>/dev/stdout|grep -i "error: target not found: "|sed "s|error: target not found: ||g"`;do
sed -i "/$f/d" ${script_path}/packages.${arch}
done
rm installtest.${arch}
    if [ $arch = "aarch64" ];then
cat ${script_path}/packages.${arch}|tr \\n \  |sed "s| linux | linux-aarch64 linux-aarch64-headers raspberrypi-bootloader firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect |g;s| linux-headers | |g"|tr \  \\n |sort|uniq > pkg.$arch
mv pkg.$arch ${script_path}/packages.${arch}
fi
}
make_packages() {
while true;do
if pacstrap -C "${work_dir}/pacman.${arch}.conf" -M -G "${work_dir}/${arch}/airootfs" --needed --overwrite \* `cat ${script_path}/packages.$arch|tr \\\\n \  `;then
break
else
continue
fi
done
rm ${script_path}/packages.${arch} ${script_path}/pacman.${arch}.conf 
}

make_setup_mkinitcpio() {
    local _hook
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/install
    for _hook in archiso archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/install
    done
    sed -i 's|cow_spacesize="256M"|cow_spacesize=\`cat /proc/meminfo\|grep -i available\|cut -f 2 -d :\|sed "s\| \|\|g;s\|kB\|K\|g"\`|g' ${work_dir}/${arch}/airootfs/etc/initcpio/hooks/archiso
    cp /usr/lib/initcpio/install/archiso_kms ${work_dir}/${arch}/airootfs/etc/initcpio/install
    cp ${script_path}/mkinitcpio.conf ${work_dir}/${arch}/airootfs/etc/mkinitcpio-archiso.conf
}

# Customize installation (airootfs)
make_customize_airootfs() {
    cp -af ${script_path}/airootfs ${work_dir}/${arch}

    case "$arch" in
x86_64)
curl -o ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist 'https://archlinux.org/mirrorlist/?country=all&protocol=http&use_mirror_status=on'
;;
i686)
curl -sL https://git.archlinux32.org/packages/plain/core/pacman-mirrorlist/mirrorlist|sed "s|#Server|Server|g" > "${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist"
;;
esac

arch-chroot "${work_dir}/${arch}/airootfs" /root/customize_airootfs.sh ${arch}
rm -rf ${work_dir}/${arch}/airootfs/var/cache/pacman/pkg/*
rm -rf ${work_dir}/${arch}/airootfs/etc/pacman.d/gnupg
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_boot() {
mkdir -p ${work_dir}/iso
mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
if [ -e ${work_dir}/${arch}/airootfs/boot/archiso.img ];then
    cp ${work_dir}/${arch}/airootfs/boot/archiso.img ${work_dir}/iso/${install_dir}/boot/${arch}/archiso.img
    fi
if [ -e ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ];then
cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ${work_dir}/iso/${install_dir}/boot/${arch}/vmlinuz
fi
}

# Add other aditional/extra files to ${install_dir}/boot/
make_boot_extra() {
    if [ -e ${work_dir}/${arch}/airootfs/boot/memtest86+/memtest.bin ];then
cp ${work_dir}/${arch}/airootfs/boot/memtest86+/memtest.bin ${work_dir}/iso/${install_dir}/boot/memtest
    fi
if [ -e ${work_dir}/${arch}/airootfs/usr/share/licenses/common/GPL2/license.txt ];then
cp ${work_dir}/${arch}/airootfs/usr/share/licenses/common/GPL2/license.txt ${work_dir}/iso/${install_dir}/boot/memtest.COPYING
    fi
if [ -e ${work_dir}/${arch}/airootfs/boot/intel-ucode.img ];then
cp ${work_dir}/${arch}/airootfs/boot/intel-ucode.img ${work_dir}/iso/${install_dir}/boot/intel_ucode.img
    fi
if [ -e ${work_dir}/${arch}/airootfs/boot/amd-ucode.img ];then
cp ${work_dir}/${arch}/airootfs/boot/amd-ucode.img ${work_dir}/iso/${install_dir}/boot/amd_ucode.img
    fi
if [ -e ${work_dir}/${arch}/airootfs/usr/share/licenses/intel-ucode/LICENSE ];then
cp ${work_dir}/${arch}/airootfs/usr/share/licenses/intel-ucode/LICENSE ${work_dir}/iso/${install_dir}/boot/intel_ucode.LICENSE
fi
}
make_efi() {
cd ${script_path}
echo -n iso version: $iso_version > ${work_dir}/iso/jenux_livecd
mkdir -p ${work_dir}/iso/boot/grub
cp ${script_path}/efiboot/*.cfg ${work_dir}/iso/boot/grub
sed -i "s|%INSTALL_DIR%|${install_dir}|g" ${work_dir}/iso/boot/grub/grub.cfg
sed -i "s|%ARCHISO_LABEL%|${iso_label}|g" ${work_dir}/iso/boot/grub/grub.cfg
}
# Build airootfs filesystem image
make_prepare() {
if [ -e "${work_dir}/iso/arch/${arch}" ];then
sleep .01
else
mkdir -p "${work_dir}/iso/arch/${arch}"
fi
arch-chroot ${script_path}/${work_dir}/${arch}/airootfs /bin/pacman -Q > "${work_dir}/iso/arch/pkglist.${arch}.txt"
cd ${work_dir}/${arch}/airootfs
mksquashfs . "${script_path}/${work_dir}/iso/arch/${arch}/airootfs.sfs" -comp xz
    cd "${script_path}/${work_dir}/iso/arch/${arch}"
sha512sum airootfs.sfs > airootfs.sha512
cd ${script_path}
}

# Build ISO
make_iso() {
cd ${script_path}/${work_dir}/iso
mkdir -p unattends/android
for presetname in "current" "legacy" "custom";do
for disk in "mmcblk0" "mmcblk1" "mmcblk2" "mmcblk3" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" "sda" "sdb" "sdc" "sdd" "vda" "vdb" "vdc" "vdd" "root_only";do
export presetname=$presetname
export disk=$disk
export partmethod=e
export disklayout="  -o -n 1:2048:4096:EF02 -t 1:EF02 -c 1:BIOS  -n 2:6144:1030143:EF00 -t 2:EF00 -c 2:EFI  -N 3 -t 3:8300 -c 3:linux  "
export boot="/dev/disk/by-partlabel/EFI"
export root="/dev/disk/by-partlabel/linux"
export fmtboot=y
export fmtfs=y
export completeaction=poweroff
case $presetname in
current)
export url="https://nashcentral.duckdns.org/autobuildres/android/$presetname.iso"
;;
legacy)
export url="https://nashcentral.duckdns.org/autobuildres/android/$presetname.iso"
;;
custom)
unset url
;;
esac
echo \#android > unattends/android/$presetname-$disk-erase
echo export presetname=\'$presetname\' >> unattends/android/$presetname-$disk-erase
if [ $presetname == "custom" ];then
sleep .01
else
echo export url=\'$url\' >> unattends/android/$presetname-$disk-erase
fi
if echo $disk|grep -qw root_only;then
echo export disk=\'$disk\' >> unattends/android/$presetname-$disk-erase
else
echo export disk=\'/dev/$disk\' >> unattends/android/$presetname-$disk-erase
fi
echo export partmethod=\'$partmethod\' >> unattends/android/$presetname-$disk-erase
echo export disklayout=\'$disklayout\' >> unattends/android/$presetname-$disk-erase
echo export boot=\'$boot\' >> unattends/android/$presetname-$disk-erase
echo export root=\'$root\' >> unattends/android/$presetname-$disk-erase
echo export fmtboot=\'$fmtboot\' >> unattends/android/$presetname-$disk-erase
echo export fmtfs=\'$fmtfs\' >> unattends/android/$presetname-$disk-erase
echo export completeaction=\'$completeaction\' >> unattends/android/$presetname-$disk-erase
done
done
mkdir -p unattends/jenux
for crypttype in "encrypted" "unencrypted";do
for presetname in "base" "basegui" "gnome" "mate" "kodi" "plasma" "retroarch" "all";do
for disk in "mmcblk0" "mmcblk1" "mmcblk2" "mmcblk3" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" "sda" "sdb" "sdc" "sdd" "vda" "vdb" "vdc" "vdd" "root_only";do
export disk=$disk
export partmethod=e
export disklayout="  -o -n 1:2048:4096:EF02 -t 1:EF02 -c 1:BIOS  -n 2:6144:1030143:EF00 -t 2:EF00 -c 2:EFI  -N 3 -t 3:8300 -c 3:linux  "
export boot="/dev/disk/by-partlabel/EFI"
export root="/dev/disk/by-partlabel/linux"
if echo $crypttype|grep -qw encrypted;then
export encrypt=y
else
export encrypt=n
fi
export cryptkey=
export fmtboot=y
export fmtfs=y
export presetname=$presetname
export kerntype=linux
export completeaction=poweroff
export accessibility="1"
export host="myhostname"
export name="My_Name"
export user=myname
export pass=mysupersecretandsecurepassword12345
export encrypthome=1
echo \#jenux > unattends/jenux/$presetname-$disk-$crypttype-erase
if echo $disk|grep -qw root_only;then
echo export disk=\'$disk\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
else
echo export disk=\'/dev/$disk\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
fi
echo export partmethod=\'$partmethod\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export disklayout=\'$disklayout\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export boot=\'$boot\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export root=\'$root\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export fmtboot=\'$fmtboot\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export fmtfs=\'$fmtfs\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export encrypt=\'$encrypt\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export cryptkey=\'$cryptkey\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export presetname=\'$presetname\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export kerntype=\'$kerntype\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo export completeaction=\'$completeaction\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo \#export accessibility=\'$accessibility\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo \#export host=\'$host\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo \#export name=\'$name\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo \#export user=\'$user\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo \#export pass=\'$pass\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
echo \#export encrypthome=\'$encrypthome\' >> unattends/jenux/$presetname-$disk-$crypttype-erase
done
done
done
mkdir -p unattends/nbd
for disk in "mmcblk0" "mmcblk1" "mmcblk2" "mmcblk3" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" "sda" "sdb" "sdc" "sdd" "vda" "vdb" "vdc" "vdd" "sr0" "sr1" "sr2" "sr3";do
echo \#nbd > unattends/nbd/$disk
echo /dev/$disk >> unattends/nbd/$disk
done
mkdir -p unattends/pi
for arch in "armv7h" "aarch64";do
case "$arch" in
armv7h)
echo raspberry pi 2\|rpi_2 >> /tmp/devlist
echo raspberry pi 2 with vendor firmware\|rpi-vfw_2 >> /tmp/devlist
echo raspberry pi 3\|rpi_3 >> /tmp/devlist
echo raspberry pi 3 with vendor firmware\|rpi-vfw_3 >> /tmp/devlist
echo raspberry pi 4\|rpi_4 >> /tmp/devlist
echo raspberry pi 4 with vendor firmware\|rpi-vfw_4 >> /tmp/devlist
export transtype=arm
;;
aarch64)
echo raspberry pi 02\|rpi_02 >> /tmp/devlist
echo raspberry pi 02 with vendor firmware\|rpi-vfw_02 >> /tmp/devlist
echo raspberry pi 3\|rpi_3 >> /tmp/devlist
echo raspberry pi 3 with vendor firmware\|rpi-vfw_3 >> /tmp/devlist
echo raspberry pi 4\|rpi_4 >> /tmp/devlist
echo raspberry pi 4 with vendor firmware\|rpi-vfw_4 >> /tmp/devlist
echo raspberry pi 5\|rpi_5 >> /tmp/devlist
echo raspberry pi 5 with vendor firmware\|rpi-vfw_5 >> /tmp/devlist
echo Pinephone\|pine_phone >> /tmp/devlist
export transtype=aarch64
;;
esac
for device in `cat /tmp/devlist|cut -f 2 -d \|`;do
export devtype=`echo $device|cut -f 2 -d \||cut -f 1 -d _`
export devid=`echo $device|cut -f 2 -d \|`
case "$devid" in
rpi_02)
export devpkgs="linux-aarch64 linux-aarch64-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
rpi-vfw_02)
export devpkgs="linux-rpi linux-rpi-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
rpi_2)
export devpkgs="linux-armv7 linux-armv7-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi fbdetect"
;;
rpi-vfw_2)
export devpkgs="linux-rpi linux-rpi-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi fbdetect"
;;
rpi_3)
if echo $arch|grep -qw armv7h;then
export devpkgs="linux-armv7 linux-armv7-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
fi
if echo $arch|grep -qw aarch64;then
export devpkgs="linux-aarch64 linux-aarch64-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
fi
;;
rpi-vfw_3)
export devpkgs="linux-rpi linux-rpi-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
rpi_4)
export devpkgs="linux-aarch64 linux-aarch64-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
rpi-vfw_4)
export devpkgs="linux-rpi linux-rpi-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
rpi_5)
export devpkgs="linux-aarch64 linux-aarch64-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
rpi-vfw_5)
export devpkgs="linux-rpi linux-rpi-headers raspberrypi-bootloader raspberrypi-bootloader-x firmware-raspberrypi pi-bluetooth hciattach-rpi3 fbdetect"
;;
pine_phone)
export devpkgs="alsa-ucm-pinephone anx7688-firmware danctnix-tweaks danctnix-usb-tethering device-pine64-pinephone eg25-manager libgpiod linux-megi linux-megi-headers  ov5640-firmware rtl8723bt-firmware uboot-tools zramswap bluez-utils pi-bluetooth"
;;
esac
export blueans="n"
export macaddr=""
export completeaction="poweroff"
export accessibility="1"
export host="myhostname"
export name="My_Name"
export user=myname
export pass=mysupersecretandsecurepassword12345
export encrypthome=1
for disk in "mmcblk0" "mmcblk1" "mmcblk2" "mmcblk3" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" "sda" "sdb" "sdc" "sdd" "vda" "vdb" "vdc" "vdd" "root_only";do
for preset in "base" "basegui" "gnome" "mate" "kodi" "plasma" "retroarch" "all";do
echo \#pi > unattends/pi/$preset-$disk-$arch-$devid
if echo $disk|grep -qw root_only;then
echo export disk=\'$disk\' >> unattends/pi/$preset-$disk-$arch-$devid
else
echo export disk=\'/dev/$disk\' >> unattends/pi/$preset-$disk-$arch-$devid
fi
echo export arch=\'$arch\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export transtype=\'$transtype\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export device=\'$device\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export devid=\'$devid\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export devpkgs=\'$devpkgs\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export devtype=\'$devtype\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export preset=\'$preset\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export blueans=\'$blueans\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export macaddr=\'$macaddr\' >> unattends/pi/$preset-$disk-$arch-$devid
echo export completeaction=\'$completeaction\' >> unattends/pi/$preset-$disk-$arch-$devid
echo \#export accessibility=\'$accessibility\' >> unattends/pi/$preset-$disk-$arch-$devid
echo \#export host=\'$host\' >> unattends/pi/$preset-$disk-$arch-$devid
echo \#export name=\'$name\' >> unattends/pi/$preset-$disk-$arch-$devid
echo \#export user=\'$user\' >> unattends/pi/$preset-$disk-$arch-$devid
echo \#export pass=\'$pass\' >> unattends/pi/$preset-$disk-$arch-$devid
echo \#export encrypthome=\'$encrypthome\' >> unattends/pi/$preset-$disk-$arch-$devid
done
done
done
done
rm /tmp/devlist
for f in `find ./unattends|grep root_only`;do
for edit in "partmethod=" "disklayout=" "boot=" "root=" "fmtboot=" "fmtfs=";do
sed -i /$edit/d $f
done
done
cat > "${script_path}/${work_dir}/iso/rootpasswd.sample" <<EOF
#This is a sample configuration which lists all variables currently supported by the jenux grub boot logic. To set any of these variables, place a file called rootpasswd in the root of any grub supported file system, i.e. ext4, ntfs, fat32, etc
#supported variables:
#lowram, if set, instructs the initial ramdisk not to copy the content of the airootfs.sfs, i.e. root file system, into ram. Note: if using an unattend file on this media, lowram must be set, unless using a separate device for unattend files, customizable using the unattenddev parameter.
#example:
#lowram=1
#nochecksum
#instructs the ramdisk not to check the integrity of the rootfs before either copying it into ram, the default, or running it from the media
#example:
#nochecksum=1
#passwd
#used to automatically enable ssh using a specific password, please note: this password will be visible in/proc/cmdline for the duration of the live system boot
#example:
#passwd=somesupersecretpassword
#port
#used to set the port on which ssh will listen, note: passwd must be defined to enable ssh, setting port without passwd will result in undefined behavior
#example:
#port=2222
#fwdport
#if connected to a network supporting upnp, requests that an IGD forward the ssh port to allow access from the internet
#example:
#fwdport=1
#extport
#if fwdport is set, specifies the external port that ssh will be available on. If not set, the external and internal ports will match
#example:
#extport=2222
#kernelopts
#used to pass parameters to the kernel
#example:
#kernelopts="console=ttyS0,115200"
#wifissid
#triggers automatic connection to a wifi network with the given ssid, if a wifi adapter is present
#example:
#wifissid=mynetwork
#wifisectype
#a wireless security type supported by NetworkManager's wifi-sec.key-mgmt property, if left empty, defaults to wpa-psk
#example:
#wifisectype=wpa-psk
#wifisecproto
#a security protocol supported by NetworkManager's wifi-sec.proto property, If left empty, defaults to rsn
#example:
#wifisecproto=rsn
#wifipass
#gives the password, wep, wpa, wpa2, wpa3, for the network specified with wifissid. Not setting wifissid will result in undefined behavior
#example:
#wifipass=mywifisupersecretandsecurepassword12345
#nospeech
#if set, turns off accessibility in the installer, also tells the installed android and jenux/arm systems not to activate accessibility features during first time configuration, can be reversed by the user during setup
#example:
#nospeech=1
#script:
#used to give the location of a script which will be executed after the package manager initialization, but before execution of the main menu. Both the format and restrictions relating to this parameter match with the below unattend directive. 
#examples:
#script=/scripts/unattend_create
#script=http://192.168.1.35/internal_scripts/install-log-remote-monitor
#scriptdev:
#specifies the device to mount containing the post login script. If not supplied, it defaults to this media.
#examples:
#scriptdev=/dev/sda3
#scriptdev=/dev/disk/by-label/data
#postscript:
#used to give the location of a script that will be run in the chroot after an installation of either android or jenux completes. Such a script may, for example, install packages that are not part of the presets, or customize the system in some other way. Your script will be run using /bin/sh.
#examples:
#postscript=/scripts/install_site_packages
#postscript=http://192.168.1.35/internal_scripts/setup_root_ssh_key
#postscriptdev:
#specifies the device to mount containing the additional post install script. If not supplied, it defaults to this media.
#examples:
#postscriptdev=/dev/sda3
#postscriptdev=/dev/disk/by-label/data
#sshkey:
#used to automatically copy a public key for ssh access, without having to use password authentication
#examples:
#sshkey=/mykey.pub
#sshkey=http://192.168.120.1/mykey
#sshkeydev:
#specifies the device to mount containing the ssh public key. If not supplied, it defaults to this media.
#examples:
#sshkeydev=/dev/sda3
#sshkeydev=/dev/disk/by-label/data
#unattend:
#used to give the location of an unattended setup file to trigger automatic installation of jenux, android, an arm device such as a raspberry pi, or a disk file for nbd access. Sample, prewritten unattend files are provided on this media. If a path is supplied, such as /unattends/nbd/sda, the unattend is searched for relative to the root of unattenddev. If unattenddev is unset, it defaults to this media. If unattend is a url, the location must be supported by curl. If unattend is a path, the file:// prefix must not be used. In order to access files on this media, lowram must be set. Multiple unattend directives are not supported and will result in undefined behavior.
#examples, please uncomment only one:
EOF
for unattend in `find unattends -type f|sort|uniq`;do
echo \#unattend=\""/"$unattend\" >> "${script_path}/${work_dir}/iso/rootpasswd.sample"
done
cat >> "${script_path}/${work_dir}/iso/rootpasswd.sample" <<EOF
#unattenddev:
#specifies the device to mount containing the unattend file. If not supplied, it defaults to this media.
#examples:
#unattenddev=/dev/sda3
#unattenddev=/dev/disk/by-label/data
#host:
#if installing jenux or creating an image for an arm device, specifies the hostname of the new system. If set, host, name, user, pass, and encrypthome must be set to complete setup. If all values are not set, setup will run interactively.
#example:
#host=myhostname
#name:
#if installing jenux or creating an image for an arm device, specifies the full name of the user of the new system. Underscores will be replaced with spaces for this field. If set, host, name, user, pass, and encrypthome must be set to complete setup. If all values are not set, setup will run interactively.
#example:
#name=my_name
#user:
#if installing jenux or creating an image for an arm device, specifies the system's username. If set, host, name, user, pass, and encrypthome must be set to complete setup. If all values are not set, setup will run interactively.
#example:
#user=myname
#pass:
#if installing jenux or creating an image for an arm device, specifies the password for the system's first user. If set, host, name, user, pass, and encrypthome must be set to complete setup. If all values are not set, setup will run interactively.
#example:
#pass=mysupersecretandsecurepassword12345
#encrypthome:
#if installing jenux or creating an image for an arm device, specifies if the system's first user should have home directory encryption. If set, host, name, user, pass, and encrypthome must be set to complete setup. If all values are not set, setup will run interactively.
#example:
#encrypthome=1
#reader
#used to select a specific screen reader, either fenrir, espeakup, or speechd-up if accessibility is enabled.
#example:
#reader=fenrir
#reader=speechd-up
#reader=espeakup
#lang
#A string of the format language_terratory.charset used to set the system language, for possible values, check https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes for language values, and https://en.wikipedia.org/wiki/ISO_3166-1#Current_codes for terratory values. Under most conditions, the charset should be UTF-8, unless you are dealing with legacy applications
#examples:
#lang=en_US.UTF-8
#lang=pt_BR.UTF-8
#nokeyrings
#if set, instructs the login script responsible for loading the main menu not to initialize the pacman keyrings, assumes that any install or package management opperations will be handled by some external agent
#example:
#nokeyrings=1
#kernel:
#The path, in any format that grub can interpret, of a custom kernel image to load, either on this media, where root is set, or on any filesystem that grub can access
#examples:
#kernel=/arch/boot/x86_64/vmlinuz
#kernel=/arch/boot/i686/vmlinuz
#kernel='(hd0,gpt3)'/boot/vmlinuz-linux
#ramdisk:
#The path, in any format that grub can interpret, of a custom ramdisk to load, either on this media, where root is set, or on any filesystem that grub can access
#examples:
#ramdisk=/arch/boot/x86_64/archiso.img
#ramdisk=/arch/boot/i686/archiso.img
#ramdisk='(hd0,gpt3)'/boot/initramfs-linux-fallback.img
#noamdmicrocode:
#if set, skips loading of AMD microcode. Note: this will not effect the ability to boot on non-AMD platforms, since mismatching microcode will be ignored by the kernel.
#example:
#noamdmicrocode=1
#nointelmicrocode:
#if set, skips loading of Intel microcode. Note: this will not effect the ability to boot on non-Intel platforms, since mismatching microcode will be ignored by the kernel.
#example:
#nointelmicrocode=1
EOF
base64 -d > pxeboot<<EOF
IyEvYmluL3NoCmV4cG9ydCBpZj0kMQppZiBbIC16ICRpZiBdO3RoZW4KZWNobyBlbnRlciBpbnRl
cmZhY2UgbmFtZQpyZWFkIGlmCmZpCmlmIGlwIGFkZHIgbHN8Z3JlcCAxOTIuMTY4LjEyMC4xfGdy
ZXAgLXF3ICRpZjt0aGVuCnNsZWVwIC4wMQplbHNlCmlwIGxpbmsgc2V0ICRpZiBkb3duCm5tY2xp
IGQgc2V0ICRpZiBtYW5hZ2VkIG5vCmlwIGxpbmsgc2V0ICRpZiB1cAppcCBhZGRyIGFkZCAxOTIu
MTY4LjEyMC4xLzI0IGRldiAkaWYKZmkKZXhwb3J0IG93bmVyPWBscyAtbGF8aGVhZCAtbiAyfHRh
aWwgLW4gMXxhd2sgJ3twcmludCAkM30nYApjYXQgPiAvdG1wL3B4ZS5jb25mPDxFT0YKbm8tZGFl
bW9uCnVzZXI9JG93bmVyCnBvcnQ9MAppbnRlcmZhY2U9JGlmCmJpbmQtaW50ZXJmYWNlcwpkaGNw
LXJhbmdlPTE5Mi4xNjguMTIwLjIsMTkyLjE2OC4xMjAuMjU0LDEyaApkaGNwLW1hdGNoPXNldDpi
aW9zLG9wdGlvbjpjbGllbnQtYXJjaCwwCmRoY3AtbWF0Y2g9c2V0OmVmaS14ODYsb3B0aW9uOmNs
aWVudC1hcmNoLDYKZGhjcC1tYXRjaD1zZXQ6ZWZpLXg4Nl82NCxvcHRpb246Y2xpZW50LWFyY2gs
NwpkaGNwLW1hdGNoPXNldDplZmkteDg2XzY0LG9wdGlvbjpjbGllbnQtYXJjaCw5CmRoY3AtbWF0
Y2g9c2V0OmVmaS1hcm02NCxvcHRpb246Y2xpZW50LWFyY2gsMTEKZGhjcC1ib290PXRhZzpiaW9z
LCIuL2Jvb3QvZ3J1Yi9pMzg2LXBjL2NvcmUuMCIKZGhjcC1ib290PXRhZzplZmkteDg2LCIuL2Jv
b3QvZ3J1Yi9pMzg2LWVmaS9jb3JlLmVmaSIKZGhjcC1ib290PXRhZzplZmkteDg2XzY0LCIuL2Jv
b3QvZ3J1Yi94ODZfNjQtZWZpL2NvcmUuZWZpIgpkaGNwLWJvb3Q9dGFnOmVmaS1hcm02NCwiLi9i
b290L2dydWIvYXJtNjQtZWZpL2NvcmUuZWZpIgplbmFibGUtdGZ0cAp0ZnRwLXJvb3Q9JFBXRApF
T0YKZGFya2h0dHBkIC4gLS1hZGRyIDE5Mi4xNjguMTIwLjEgLS1uby1saXN0aW5nIC0tdWlkICRv
d25lciYKZXhwb3J0IGh0dHBwaWQ9YGVjaG8gJCFgCmRuc21hc3EgLUMgL3RtcC9weGUuY29uZiYK
ZXhwb3J0IGRoY3BwaWQ9YHBncmVwIC1hZiBkbnNtYXNxfGdyZXAgLXcgJ2Ruc21hc3EgLUMgL3Rt
cC9weGUuY29uZid8c2VkIC9ncmVwL2R8Y3V0IC1mIDEgLWQgXCAgYAp3aGlsZSB0cnVlO2RvCnRy
YXAgImlwIGFkZHIgZGVsIDE5Mi4xNjguMTIwLjEvMjQgZGV2ICRpZjtpcCBsaW5rIHNldCAkaWYg
ZG93bjtybSAvdG1wL3B4ZS5jb25mO2V4aXQiIGludApzbGVlcCAuMjUKZG9uZQo=
EOF
chmod 755 pxeboot
base64 -d > support.png<<EOF
iVBORw0KGgoAAAANSUhEUgAAAKsAAACrAQMAAAAjJv5aAAAABlBMVEUAAAD///+l2Z/dAAAAAnRS
TlP//8i138cAAAAJcEhZcwAACxIAAAsSAdLdfvwAAAK5SURBVEiJ5Zc9susgDIXloaCLN8AM26Bj
S/EG7HgD8Zbo2AYzbAB3FIz1Ds79aV4j2ptxEX/JgCWOjmTi/37ob+NCtJKZKm2xTdGegSY5Prk9
PZ/BTKEt1UwRRI6DWWp6+Pz2NAXeIy1DeMPd/YAb52MUL1W9vSFNT595DDOCS0TYoU0BO/wEL8DI
9xLN7/V7DAKMT6F8hoZVX04dv4IQ4OLaHNUZE2mzkkLQsxyfFZLJl+bLq+KwbpvkuOi2MM3B7tyQ
8q2qU45PVnvFo3UMEXHF+YsxhzRHmiPCNeQsB3vI8RmRbHpSFyDCPeoIvsis3mwVZw45W2Rrl2Pm
zGxfZF8Qsuvh8gAOadVtpUSOX54e2kwDuNpLw2mwfC4urf5TUkIc2wr14S6iLhXXvMvx5WAw5kG4
aHU0Vx7AJyfycBdbyB7B4DvLMerg7dND9zN/uXyENstx0UQ4qLsuH90wzAC+vC06rQSXQp7Uzl8a
lGEyT1yozoCUwyrsLsfI0Mmw/7YF+9ZYWw3gqzeQfN7uO9XbRAcwqUKKQy63Dc/1K1UijHwvFcWd
L98If3EfDcowQ3QVVUUPiNHBMtUhx5dOT7L3Y/LbmRnWNYAd/Dtttcu5OFRnW0YwHFcd0SDEi+4G
K8doaEWjk0CGfR8OZpJj7iNP72kLiinixx/jEODLqR3ygQARou6DwynHBRpkOC6MkwjW+x2lCDM6
SfeYtLHt4fYvYnz5tFSoJuNJu3xiPgYw8RHV5eFY5gm3oM/EIcO9z0eYBOoSO5henXLcZx/XqwFT
IapqYrvLcbeEql6EESy/epQfh5BhzIMbYzTG2m113be2AYzxNhLaGqrhjRkKmwzhpcJj0FcxD6KZ
fIpbjLfa5YOXhqPi2O05gO/3hp3THMyq8a8RfBs2okzIUw8xmkWOZa9YfwH/AzZWQP+EEZJUAAAA
AElFTkSuQmCC
EOF
base64 -d > support.vcf<<EOF
QkVHSU46VkNBUkQKVkVSU0lPTjoyLjEKTjpEYW5pZWwgTmFzaDs7OwpGTjpOYXNoO0RhbmllbApP
Ukc6ClRJVExFOlRlY2huaWNhbCBDb25zdWx0YW50CkVNQUlMO0hPTUU6ZG5sLm5hc2hAZ21haWwu
Y29tClRFTDtDRUxMOisxICg5MTQpIDk3OS0xMzk1ClVSTDpodHRwczovL25hc2hjZW50cmFsLmR1
Y2tkbnMub3JnCmVuZDp2Y2FyZAo=
EOF
cd ${script_path}
if [ -e ${out_dir} ];then
sleep .01
else
mkdir -p ${out_dir}
fi
cd ${script_path}/${work_dir}/iso
git log > "${iso_name}-${iso_version}-tripple.iso.changelog"
git log > "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-tripple.iso.changelog"
export rootsize=`du -m --total .|tail -n 1|cut -f 1`
export contsize=$(($rootsize+600))"M"
truncate -s $contsize "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-tripple.iso"
losetup -P -f "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-tripple.iso"
export loopdev=`losetup|grep -w "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-tripple.iso"|cut -f 1 -d \  `
sgdisk  -o -n 1:2048:4096:EF02 -t 1:EF02 -c 1:BIOS  -n 2:6144:1030143:EF00 -t 2:EF00 -c 2:ISOEFI -N 3 -t 3:0700 -c 3:linuxiso $loopdev
sgdisk -h 2:EE $loopdev
fdisk -t dos $loopdev<<EOF
t
1
c
w
EOF
partprobe $loopdev
mkfs.vfat -n ISOEFI $loopdev"p2"
mkfs.vfat -n ${iso_label} $loopdev"p3"
mount $loopdev"p3" /mnt
mkdir -p /mnt/EFI
mount $loopdev"p2" /mnt/EFI
cp -rf * /mnt
cp -rf ../x86_64/airootfs/usr/share/shim-signed/EFI /mnt/EFI
export tmpdir=`mktemp -d`
export sbgen=2
export grubver=`grub-mkstandalone --version|sed "s|grub-mkstandalone (GRUB) ||g"`
cat > $tmpdir/sbat.csv <<EOF
sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md
grub,$sbgen,Free Software Foundation,grub,$grubver,https://www.gnu.org/software/grub/
EOF
cp -Lrf ${script_path}/${work_dir}/aarch64/airootfs/boot/* /mnt/EFI
rm -rf /mnt/EFI/Image.gz /mnt/EFI/vmlinuz-linux /mnt/EFI/initramfs-linux* /mnt/EFI/amd-ucode.img /mnt/EFI/archiso.img /mnt/EFI/firmware
grub-install -d ${script_path}/${work_dir}/aarch64/airootfs/usr/lib/grub/arm64-efi --boot-directory /mnt/boot --force-file-id --modules="echo part_gpt part_msdos iso9660 udf fat search_fs_file search_label all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --no-nvram --sbat $tmpdir/sbat.csv --target arm64-efi --efi-directory /mnt/EFI
grub-install -d ${script_path}/${work_dir}/x86_64/airootfs/usr/lib/grub/x86_64-efi --boot-directory /mnt/boot --force-file-id --modules="echo play usbms cpuid part_gpt part_msdos iso9660 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --no-nvram --sbat $tmpdir/sbat.csv --target x86_64-efi --efi-directory /mnt/EFI
grub-install -d ${script_path}/${work_dir}/x86_64/airootfs/usr/lib/grub/i386-efi --boot-directory /mnt/boot --force-file-id --modules="echo play usbms cpuid part_gpt part_msdos iso9660 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --no-nvram --sbat $tmpdir/sbat.csv --target i386-efi --efi-directory /mnt/EFI
grub-install -d ${script_path}/${work_dir}/x86_64/airootfs/usr/lib/grub/i386-pc --boot-directory /mnt/boot --force-file-id --modules="echo play usbms cpuid part_gpt part_msdos iso9660 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --target i386-pc $loopdev
grub-mknetdir --net-directory=/mnt --sbat=$tmpdir/sbat.csv -d ${script_path}/${work_dir}/x86_64/airootfs/usr/lib/grub/x86_64-efi
grub-mknetdir --net-directory=/mnt --sbat=$tmpdir/sbat.csv -d ${script_path}/${work_dir}/x86_64/airootfs/usr/lib/grub/i386-efi
grub-mknetdir --net-directory=/mnt --sbat=$tmpdir/sbat.csv -d ${script_path}/${work_dir}/aarch64/airootfs/usr/lib/grub/arm64-efi
grub-mknetdir --net-directory=/mnt -d ${script_path}/${work_dir}/x86_64/airootfs/usr/lib/grub/i386-pc
mv /mnt/EFI/EFI/boot/bootaa64.efi /mnt/EFI/EFI/boot/bootaa64.efi.shim
mv /mnt/EFI/EFI/arch/grubaa64.efi /mnt/EFI/EFI/boot/bootaa64.efi
openssl req -new -x509 -newkey rsa:4096 -days 365000 -keyout $tmpdir/jenux.key -out $tmpdir/jenux.crt -nodes -subj "/CN=Jenux ISO Secure Boot/"
openssl x509 -in $tmpdir/jenux.crt -out $tmpdir/jenux-iso.cer -outform DER
for f in `find /mnt -type f|grep vmlinuz`;do
mv $f $f.unsigned
sbsign --key $tmpdir/jenux.key --cert $tmpdir/jenux.crt --output $f $f.unsigned
rm $f.unsigned
done
for f in `find /mnt -type f|grep core.efi`;do
if file $f|grep -qw EFI\ application;then
mv $f $f.unsigned
sbsign --key $tmpdir/jenux.key --cert $tmpdir/jenux.crt --output $f $f.unsigned
rm $f.unsigned
fi
done
for f in `find /mnt -type f|sed "/shim/d;/mm/d;/fb/d;/EFI\/boot/d"|grep .efi|sed /mod/d`;do
if file $f|grep -qw EFI\ application;then
mv $f $f.unsigned
sbsign --key $tmpdir/jenux.key --cert $tmpdir/jenux.crt --output $f $f.unsigned
rm $f.unsigned
fi
done
rm $tmpdir/jenux.key
mv $tmpdir/jenux.crt /mnt/EFI
cd /mnt/EFI
curl -Lo efi3.zip https://github.com/pftf/RPi3/releases/download/v1.39/RPi3_UEFI_Firmware_v1.39.zip
unzip -o efi3.zip
rm efi3.zip Readme.md firmware/Readme.txt
mv config.txt config3.txt
mv RPI_EFI.fd RPI3_EFI.fd
sed -i "s|RPI_EFI.fd|RPI3_EFI.fd|g" config3.txt
curl -Lo efi4.zip https://github.com/pftf/RPi4/releases/download/v1.35/RPi4_UEFI_Firmware_v1.35.zip
unzip -o efi4.zip
rm efi4.zip Readme.md firmware/Readme.txt
mv config.txt config4.txt
mv RPI_EFI.fd RPI4_EFI.fd
sed -i "s|RPI_EFI.fd|RPI4_EFI.fd|g" config4.txt
curl -Lo efi5.zip 'https://github.com/worproject/rpi5-uefi/releases/download/v0.2/RPi5_UEFI_Release_v0.2.zip'
unzip -o efi5.zip
mv config.txt config5.txt
mv RPI_EFI.fd RPI5_EFI.fd
sed -i "s|RPI_EFI.fd|RPI5_EFI.fd|g" config5.txt
rm efi5.zip
echo \[pi3\] > config.txt
cat config3.txt >> config.txt
rm config3.txt
echo \[pi4\] >> config.txt
cat config4.txt >> config.txt
rm config4.txt
echo \[pi5\] >> config.txt
cat config5.txt >> config.txt
rm config5.txt
echo \[all\] >> config.txt
echo dtparam=audio=on >> config.txt
echo dtparam=krnbt=on >> config.txt
sed -i "/dtoverlay=miniuart-bt/d" config.txt
unix2dos config.txt
cd $OLDPWD
umount /mnt/EFI /mnt
losetup -d $loopdev
rm -rf $tmpdir
cd "${script_path}/${out_dir}"
sha512sum "${iso_name}-${iso_version}-tripple.iso" > "${iso_name}-${iso_version}-tripple.iso.sha512"
cd ${script_path}
ls -sh "${out_dir}/${iso_name}-${iso_version}-tripple.iso"
}

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    _usage 1
fi

if [[ ${arch} != x86_64 ]]; then
    echo "This script needs to be run on x86_64"
    _usage 1
fi

while getopts 'N:V:L:D:w:o:vh' arg; do
    case "${arg}" in
        N) iso_name="${OPTARG}" ;;
        V) iso_version="${OPTARG}" ;;
        L) iso_label="${OPTARG}" ;;
        D) install_dir="${OPTARG}" ;;
        w) work_dir="${OPTARG}" ;;
        o) out_dir="${OPTARG}" ;;
        v) verbose="-v" ;;
        h) _usage 0 ;;
        *)
           echo "Invalid argument '${arg}'"
           _usage 1
           ;;
    esac
done

mkdir -p ${work_dir}


# Do all stuff for each airootfs
for arch in "i686" "x86_64" "aarch64"; do
run_once make_pacman_conf
run_once make_packages
run_once make_setup_mkinitcpio
run_once make_customize_airootfs
run_once make_boot
run_once make_boot_extra
run_once make_prepare
case "$arch" in
x86_64)
run_once make_efi
;;
esac
done



# Do all stuff for "iso"
run_once make_iso
rm -rf ${work_dir} ${install_dir}
