#!/bin/bash
umask 022
if [ -e .env ];then
source .env
fi
if [ -z $jenux_iso_arch ]||[ -z $jenux_iso_livemode ]||[ -z $jenux_iso_preset ];then
if [ -z $jenux_iso_arch ];then
echo jenux_iso_arch is not set
else
echo jenux_iso_arch: $jenux_iso_arch
fi
if [ -z $jenux_iso_livemode ];then
echo jenux_iso_livemode is not set
else
echo jenux_iso_livemode: $jenux_iso_livemode
fi
if [ -z $jenux_iso_preset ];then
echo jenux_iso_preset is not set
else
echo jenux_iso_preset: $jenux_iso_preset
fi
echo environment error, see .venv.example, all vars must be set.
exit 1
fi
if echo $jenux_iso_arch|grep -qw _detect_;then
export jenux_iso_arch=`uname -m`
fi
export preset=$jenux_iso_preset
export arch=$jenux_iso_arch
if echo $jenux_iso_arch|grep -iqw all;then
unset arch
fi
if echo $jenux_iso_livemode|grep -iqw 1;then
export livebuild=livebuild
iso_name=Jenux-live-$preset
else
export livebuild=nolive
iso_name=Jenux
fi
iso_label="JENUX_$(date +%Y)"
iso_version=$(date +%Y.%m.%d)
install_dir=arch
work_dir=work
out_dir=out
verbose="-v"
script_path=$(readlink -f ${0%/*})
if [ -e /.dockerenv ];then
mount -t devtmpfs /dev /dev
fi
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
export mygpgdir=$PWD
if [ -e $mygpgdir/gpg.tar ];then
sleep .01
else
cd /
tar -cf $mygpgdir/gpg.tar etc/pacman.d/gnupg
cd $mygpgdir
fi
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
    while true;do
if curl -s -Lo ${script_path}/pacman.${arch}.conf https://nashcentral.duckdns.org/autobuildres/pi/pacman.$arch.conf;then
break
else
continue
fi
done
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
rm -rf /etc/pacman.d/gnupg
pacman-key --init
echo allow-weak-key-signatures >> /etc/pacman.d/gnupg/gpg.conf
pacman-key --populate
for k in `cat /usr/share/pacman/keyrings/*.gpg|gpg --list-options show-std-notations --show-keys 2>/dev/null|sed "/pub/d;/uid/d;/sub/d;/by/d;/Revocable/d"|tr -s \\n`;do
if pacman-key -l|grep -qw $k;then
export keylist=$keylist" "$k
fi
done
pacman-key -r $keylist
pacman-key --lsign $keylist
rm *.pkg* mirrors.tar
cd $prepkgdir
else
while true;do
if curl -Lo ${script_path}/pacman.${arch}.conf https://nashcentral.duckdns.org/autobuildres/linux/pacman.${arch}.conf;then
break
else
continue
fi
done
fi
if [ -e /.dockerenv ];then
cp ${script_path}/pacman.$arch.conf ${work_dir}/pacman.${arch}.conf
else
sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n ${_cache_dirs[@]})|g" ${script_path}/pacman.$arch.conf > ${work_dir}/pacman.${arch}.conf
fi
if [ $arch = "aarch64" ];then
sed -i "s|Include = \/etc\/pacman.d\/mirrorlist|Include = ${work_dir}\/${arch}\/airootfs\/etc\/pacman.d\/mirrorlist|g" "${work_dir}/pacman.${arch}.conf"
fi
if [ $arch = "i686" ];then
mkdir -p "${work_dir}/${arch}/airootfs/etc/pacman.d"
while true;do
if curl -Lo "${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist" https://git.archlinux32.org/packages/plain/core/pacman-mirrorlist/mirrorlist;then
break
else
continue
fi
done
sed -i "s|#Server|Server|g" "${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist"
sed -i "s|Include = \/etc\/pacman.d\/mirrorlist|Include = ${work_dir}\/${arch}\/airootfs\/etc\/pacman.d\/mirrorlist|g" "${work_dir}/pacman.${arch}.conf"
while true;do
export mirrorurl=`cat ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist|grep -i server|head -n 1|sed "s|\\$arch|$arch|g;s|\\$repo|core|g;s|Server = ||g"`
export keyringurl=`lynx --dump -listonly -nonumbers $mirrorurl|grep archlinux32-keyring|grep .tar|sed "/transition/d;/.sig/d"|tail -n 1|cut -f 4 -d \  `
if curl -LO $keyringurl;then
break
else
continue
fi
done
pacman --needed --noconfirm -U *.pkg*
rm -rf /etc/pacman.d/gnupg
pacman-key --init
echo allow-weak-key-signatures >> /etc/pacman.d/gnupg/gpg.conf
pacman-key --populate
for k in `cat /usr/share/pacman/keyrings/*.gpg|gpg --list-options show-std-notations --show-keys 2>/dev/null|sed "/pub/d;/uid/d;/sub/d;/by/d;/Revocable/d"|tr -s \\n`;do
if pacman-key -l|grep -qw $k;then
export keylist=$keylist" "$k
fi
done
pacman-key -r $keylist
pacman-key --lsign $keylist
rm *.pkg*
fi
if [ $arch = "x86_64" ];then
mkdir -p "${work_dir}/${arch}/airootfs/etc/pacman.d"
while true;do
if curl -L https://archlinux.org/packages/core/any/pacman-mirrorlist/download/|tar --zstd -C ${work_dir}/${arch}/airootfs -x etc/pacman.d/mirrorlist;then
break
else
continue
fi
done
sed -i "s|#Server|Server|g" "${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist"
sed -i "s|Include = \/etc\/pacman.d\/mirrorlist|Include = ${work_dir}\/${arch}\/airootfs\/etc\/pacman.d\/mirrorlist|g" "${work_dir}/pacman.${arch}.conf"
while true;do
export mirrorurl=`cat ${work_dir}/${arch}/airootfs/etc/pacman.d/mirrorlist|grep -i server|head -n 1|sed "s|\\$arch|$arch|g;s|\\$repo|core|g;s|Server = ||g"`
export keyringurl=`lynx --dump -listonly -nonumbers $mirrorurl|grep archlinux-keyring|grep .tar|sed "/transition/d;/.sig/d"|tail -n 1|cut -f 4 -d \  `
if curl -LO $keyringurl;then
break
else
continue
fi
done
pacman --needed --noconfirm -U *.pkg*
rm -rf /etc/pacman.d/gnupg
pacman-key --init
echo allow-weak-key-signatures >> /etc/pacman.d/gnupg/gpg.conf
pacman-key --populate
for k in `cat /usr/share/pacman/keyrings/*.gpg|gpg --list-options show-std-notations --show-keys 2>/dev/null|sed "/pub/d;/uid/d;/sub/d;/by/d;/Revocable/d"|tr -s \\n`;do
if pacman-key -l|grep -qw $k;then
export keylist=$keylist" "$k
fi
done
pacman-key -r $keylist
pacman-key --lsign $keylist
rm *.pkg*
fi
mkdir -p ${work_dir}/${arch}/airootfs/var/lib/pacman/
cat ${work_dir}/pacman.${arch}.conf|grep -F \[|grep -F \]|sed "/#/d;/\[options\]/d"|tr \\n \  |read -r -s repodata
export repos=`echo $repodata|tr \\  \\\n|tr -d \\[|tr -d \\]`
export oldifs=$IFS
export IFS=$(echo -en \\n\\b)
for f in `echo -en $repos`;do
if [ -e ${work_dir}/${arch}/airootfs/var/lib/pacman/sync/$f.db ];then
continue
else
while true;do
if pacman --config ${work_dir}/pacman.${arch}.conf -r ${work_dir}/${arch}/airootfs -Syy;then
break
else
continue
fi
done
fi
done
export IFS=$oldifs
}
make_packages() {
while true;do
curl https://nashcentral.duckdns.org/autobuildres/linux/pkg.${preset}|tr \  \\n|sed "/pacstrap/d;/\/mnt/d;/--overwrite/d;/\\\\\*/d" > packages.${arch}
if cat packages.${arch}|grep -iqw base;then
if [ $arch = "aarch64" ];then
sed -i "/qemu-system-arm/d;/qemu-system-x86/d;/qemu-emulators-full/d;/gnome-boxes/d" packages.${arch}
fi
if [ $arch = "i686" ];then
sed -i "/qemu-img/d;/vlc/d;s|qemu-base|qemu-headless|g" packages.${arch}
fi
if echo $preset|grep -qw base ;then
true
else
for reppkg in "jack2" "virtualbox-guest-utils-nox";do
if pacman --config ${work_dir}/pacman.${arch}.conf -r ${work_dir}/${arch}/airootfs -Q 2>/dev/stdout|grep -iqw $reppkg;then
pacman --noconfirm --config ${work_dir}/pacman.${arch}.conf -r ${work_dir}/${arch}/airootfs -Rdd $reppkg
fi
done
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
break
else
continue
fi
done
while true;do
if pacstrap -C "${work_dir}/pacman.${arch}.conf" -M -G "${work_dir}/${arch}/airootfs" --needed --overwrite \* `cat ${script_path}/packages.$arch|tr \\\\n \  `;then
cd /
rm -rf etc/pacman.d/gnupg
tar -xf $mygpgdir/gpg.tar etc/pacman.d/gnupg
cd $OLDPWD
break
else
make_packages
continue
fi
done
rm ${script_path}/packages.${arch} ${script_path}/pacman.${arch}.conf 
rm -rf ${work_dir}/${arch}/airootfs/var/cache/pacman/pkg/*
}

make_setup_mkinitcpio() {
    local _hook
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
    mkdir -p ${work_dir}/${arch}/airootfs/etc/initcpio/install
    for _hook in archiso archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${work_dir}/${arch}/airootfs/etc/initcpio/install
    done
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
arch-chroot "${work_dir}/${arch}/airootfs" /root/customize_airootfs.sh ${arch} ${preset}
rm -rf ${work_dir}/${arch}/airootfs/etc/pacman.d/gnupg
if [ -e "${work_dir}/${arch}/airootfs/usr/share/jenux" ];then
sleep .01
else
mkdir -p "${work_dir}/${arch}/airootfs/usr/share/jenux"
fi
echo $preset > "${work_dir}/${arch}/airootfs/usr/share/jenux/preset"
echo -en rsync -aAXH --info=progress2 \   > "${work_dir}/${arch}/airootfs/usr/share/jenux/offline-options"
for f in `echo --exclude='/etc/systemd/system/getty@tty2.service.d' --exclude='/etc/systemd/system/getty@tty3.service.d' --exclude='/etc/systemd/system/getty@tty4.service.d' --exclude='/etc/systemd/system/getty@tty5.service.d' --exclude='/etc/systemd/system/getty@tty6.service.d' --exclude='/etc/systemd/system/getty@ttyS0.service.d' --exclude='/etc/systemd/system/getty@ttyS1.service.d' --exclude='/etc/systemd/system/getty@ttyS2.service.d' --exclude='/etc/systemd/system/getty@ttyS3.service.d' --exclude='/boot/vmlinuz-linux.rpi' --exclude='/boot/grub/grub.cfg' --exclude='/boot/archiso*' --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found/' '/usr/share/jenux/offline-options';find airootfs -type l -o -type f |sed "s|airootfs\/|\/|g"`;do
if echo $f|grep -qw - --exclude=;then
echo $f|sed "s|--exclude=|--exclude=\'|g"|tr -d \\n
echo -en \'\  
else
echo --exclude=\'$f\'
fi
done|tr \\n \  >> "${work_dir}/${arch}/airootfs/usr/share/jenux/offline-options"
echo -en / /mnt >> "${work_dir}/${arch}/airootfs/usr/share/jenux/offline-options"
chmod 755 "${work_dir}/${arch}/airootfs/usr/share/jenux/offline-options"
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_boot() {
mkdir -p ${work_dir}/iso
mkdir -p ${work_dir}/iso/${install_dir}/boot/${arch}
if [ -e ${work_dir}/${arch}/airootfs/boot/archiso.img ];then
    cp ${work_dir}/${arch}/airootfs/boot/archiso* ${work_dir}/iso/${install_dir}/boot/${arch}
    fi
if [ -e ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux ];then
cp ${work_dir}/${arch}/airootfs/boot/vmlinuz-linux* ${work_dir}/iso/${install_dir}/boot/${arch}/
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
echo -n iso version: $iso_version > ${work_dir}/iso/jenux_version
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
while true;do
if mountpoint -q ${work_dir}/${arch}/airootfs/proc;then
if umount ${work_dir}/${arch}/airootfs/proc;then
break
else
continue
fi
else
break
fi
done
if echo $buildtype|grep -iqw tripple ];then
sleep .01
else
if [ -e "${script_path}/${out_dir}" ];then
sleep .01
else
mkdir -p "${script_path}/${out_dir}"
fi
if [ -e "${script_path}/${out_dir}"/rootfs.tar ];then
sleep .01
else
export taropts=`cat usr/share/jenux/offline-options|tr \\  \\\n|grep exclude|tr \\\n \\  |sed "s|'/|'|g"`
for rootfssvc in "avahi-daemon" "fenrirscreenreader" "getty@tty1" "speech-dispatcherd";do
arch-chroot . systemctl enable $rootfssvc
done
cat > usr/bin/rootfsprep<<EOF
cp -rf /usr/share/shim-signed/EFI /boot/EFI
bootcrypt
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
echo y|fscrypt setup
systemctl disable sshcheck
rm /usr/bin/rootfsprep
EOF
chmod 755 usr/bin/rootfsprep
echo tar $taropts -cf "${script_path}/${out_dir}"/rootfs.tar .|sh
for rootfssvc in "avahi-daemon" "fenrirscreenreader" "getty@tty1" "speech-dispatcherd";do
arch-chroot . systemctl disable $rootfssvc
done
rm usr/bin/rootfsprep
fi
fi
while true;do
if mksquashfs . "${script_path}/${work_dir}/iso/arch/${arch}/airootfs.sfs" -b 16384;then
break
else
continue
fi
done
cd "${script_path}/${work_dir}/iso/arch/${arch}"
sha512sum airootfs.sfs > airootfs.sha512
cd ${script_path}
rm --one-file-system -rf ${work_dir}/${arch}/airootfs
}

# Build ISO
make_iso() {
cd ${script_path}
if [ -e ${out_dir} ];then
sleep .01
else
mkdir -p ${out_dir}
fi
cd ${script_path}/${work_dir}/iso
git -P log --all > "${iso_name}-${iso_version}-${buildtype}.changelog"
if [ -e "${script_path}/iso" ];then
cp -rf "${script_path}/iso" ..
fi
cp -rf * ${script_path}/${out_dir}
if echo $livebuild|grep -iqw livebuild;then
echo livemode=1 > ./jenux_live
fi
cp "${iso_name}-${iso_version}-${buildtype}.changelog" "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.changelog"
export bufsize=800
while true;do
export rootsize=`du -m --total .|tail -n 1|cut -f 1`
export contsize=$(($rootsize+$bufsize))"M"
truncate -s $contsize "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.iso"
losetup -P -f "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.iso"
export loopdev=`losetup|grep -w "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.iso"|cut -f 1 -d \  `
sgdisk  -o -n 1:2048:4096:EF02 -t 1:EF02 -c 1:BIOS  -n 2:6144:+750M:EF00 -t 2:EF00 -c 2:ISOEFI -N 3 -t 3:0700 -c 3:linuxiso $loopdev
partprobe $loopdev
export oldifs=$IFS
export IFS=$(echo -en \\n\\b)
for f in `cat /proc/partitions|tr -s \  |grep loop\*p\*`;do
export dev=`echo -en $f|cut -f 5 -d \  `
if [ -e /dev/$dev ];then
continue
else
export maj=`echo $f|cut -f 2 -d \  `
export min=`echo -en $f|cut -f 3 -d \  `
mknod /dev/$dev b $maj $min
fi
done
export IFS=$oldifs
mkfs.vfat -n ISOEFI $loopdev"p2"
echo y|mkfs.ext4 -L ${iso_label} $loopdev"p3"
tune2fs -O encrypt -m 0 $loopdev"p3"
mount $loopdev"p3" /mnt
mkdir -p /mnt/EFI
mount $loopdev"p2" /mnt/EFI
if [ -e "${script_path}/${work_dir}/${arch}/airootfs" ];then
sleep .01
else
mkdir -p "${script_path}/${work_dir}/${arch}/airootfs"
fi
if mountpoint "${script_path}/${work_dir}/${arch}/airootfs/proc" > /dev/null 2>/dev/null;then
umount "${script_path}/${work_dir}/${arch}/airootfs/proc"
fi
mount "${script_path}/${work_dir}/iso/arch/${arch}/airootfs.sfs" "${script_path}/${work_dir}/${arch}/airootfs"
if install_bootloader;then
cd /mnt
tar -cf "${script_path}/${out_dir}"/enroler.tar  EFI boot
export enrolerdatasize=`du -h "${script_path}/${out_dir}"/enroler.tar|cut -f 1 -d M`
export enrolerbufsize=2048
export enrolersize=$(($enrolerdatasize+$enrolerbufsize))"M"
truncate -s $enrolersize "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.enroler.iso"
export enrolerdev=`losetup -P -f "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.enroler.iso" --show`
sgdisk  -o -n 1:2048:4096:EF02 -t 1:EF02 -c 1:BIOS  -n 2:6144:+750M:EF00 -t 2:EF00 -c 2:ISOEFI -N 3 -t 3:0700 -c 3:linuxiso $enrolerdev
partprobe $enrolerdev
mkdir /fs
mkfs.vfat -n ISOEFI $enrolerdev"p2"
echo y|mkfs.ext4 -L ${iso_label} $enrolerdev"p3"
tune2fs -O encrypt -m 0 $enrolerdev"p3"
mount $enrolerdev"p3" /fs
mkdir -p /fs/EFI
mount $enrolerdev"p2" /fs/EFI
tar -C /fs -xf "${script_path}/${out_dir}"/enroler.tar
cat > /fs/boot/grub/grub.cfg<<EOF
echo key enrolement complete
play 440 440 1
play 880 880 1
halt
EOF
umount /fs/EFI /fs
losetup -d $enrolerdev
rm "${script_path}/${out_dir}"/enroler.tar
cd $OLDPWD
umount /mnt/EFI /mnt "${script_path}/${work_dir}/${arch}/airootfs"
losetup -d $loopdev
cp "${script_path}/${work_dir}/iso/rootpasswd.sample" "${script_path}/${out_dir}"
cp -rf "${script_path}/${work_dir}/iso/unattends" "${script_path}/${out_dir}"
break
else
cd ${script_path}/${work_dir}/iso
export mypid=`readlink /proc/self`"c"
export pids=`fuser -m /mnt|tr c \  |tr -s \  |sed "s|$mypid||g"`
export pids=$pids" "`fuser -m /mnt/EFI|tr c \  |tr -s \  |sed "s|$mypid||g"`
for f in `echo $pids`;do
kill -9 $f
done
umount /mnt/EFI /mnt "${script_path}/${work_dir}/${arch}/airootfs"
losetup -d $loopdev
export bufsize=$(($bufsize+200))
continue
fi
done
rm -rf $tmpdir
cd "${script_path}/${out_dir}"
sha512sum "${iso_name}-${iso_version}-${buildtype}.enroler.iso" > "${iso_name}-${iso_version}-${buildtype}.enroler.iso.sha512"
sha512sum "${iso_name}-${iso_version}-${buildtype}.iso" > "${iso_name}-${iso_version}-${buildtype}.iso.sha512"
cd ${script_path}
ls -sh "${out_dir}/${iso_name}-${iso_version}-${buildtype}.iso"
ls -sh "${out_dir}/${iso_name}-${iso_version}-${buildtype}.enroler.iso"
}
function install_bootloader
{
if cp -rf * /mnt;then
sleep .01
else
return 1
fi
if cp -rf /usr/share/shim-signed/EFI /mnt/EFI;then
sleep .01
else
return 2
fi
export tmpdir=`mktemp -d`
if cp /usr/share/grub/sbat.csv $tmpdir/sbat.csv;then
sleep .01
else
return 3
fi
if echo $prepbuilds|grep -iqw x86_64;then
if grub-install -d /usr/lib/grub/x86_64-efi --boot-directory /mnt/boot --force-file-id --modules="echo play usbms cpuid part_gpt part_msdos ext2 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --no-nvram --sbat $tmpdir/sbat.csv --target x86_64-efi --efi-directory /mnt/EFI;then
sleep .01
else
return 4
fi
if grub-mknetdir --net-directory=/mnt --sbat=$tmpdir/sbat.csv -d /usr/lib/grub/x86_64-efi --modules="echo play usbms cpuid part_gpt part_msdos ext2 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp";then
sleep .01
else
return 5
fi
if cp /mnt/boot/grub/x86_64-efi/core.efi /mnt/grubx64.efi;then
sleep .01
else
return 6
fi
fi
if echo $prepbuilds|grep -iqw x86_64||echo $prepbuilds|grep -iqw i686;then
if grub-install -d /usr/lib/grub/i386-efi --boot-directory /mnt/boot --force-file-id --modules="echo play usbms cpuid part_gpt part_msdos ext2 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --no-nvram --sbat $tmpdir/sbat.csv --target i386-efi --efi-directory /mnt/EFI;then
sleep .01
else
return 7
fi
if grub-mknetdir --net-directory=/mnt --sbat=$tmpdir/sbat.csv -d /usr/lib/grub/i386-efi --modules="echo play usbms cpuid part_gpt part_msdos ext2 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp";then
sleep .01
else
return 8
fi
if grub-install -d /usr/lib/grub/i386-pc --boot-directory /mnt/boot --force-file-id --modules="echo play usbms cpuid part_gpt part_msdos ext2 udf fat search_fs_file search_label usb_keyboard all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --target i386-pc $loopdev;then
sleep .01
else
return 9
fi
if grub-mknetdir --net-directory=/mnt -d /usr/lib/grub/i386-pc;then
sleep .01
else
return 10
fi
if cp /mnt/boot/grub/i386-efi/core.efi /mnt/grubia32.efi;then
sleep .01
else
return 11
fi
if [ -e /mnt/boot/grub/x86_64-efi/core.efi ];then
if cp /mnt/boot/grub/x86_64-efi/core.efi /mnt/grubx64.efi;then
sleep .01
else
return 12
fi
fi
fi
if echo $prepbuilds|grep -iqw aarch64;then
if [ -e ${script_path}/${work_dir}/${arch}/airootfs/boot/* ];then
if cp -Lrf ${script_path}/${work_dir}/${arch}/airootfs/boot/* /mnt/EFI;then
sleep .01
else
return 13
fi
fi
if grub-install -d ${script_path}/${work_dir}/${arch}/airootfs/usr/lib/grub/arm64-efi --boot-directory /mnt/boot --force-file-id --modules="echo part_gpt part_msdos ext2 udf fat search_fs_file search_label all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp" --no-nvram --sbat $tmpdir/sbat.csv --target arm64-efi --efi-directory /mnt/EFI;then
sleep .01
else
return 14
fi
if grub-mknetdir --net-directory=/mnt --sbat=$tmpdir/sbat.csv -d ${script_path}/${work_dir}/${arch}/airootfs/usr/lib/grub/arm64-efi --modules="echo part_gpt part_msdos ext2 udf fat search_fs_file search_label all_video test configfile normal linux ext2 ntfs exfat hfsplus net tftp";then
sleep .01
else
return 15
fi
mv /mnt/EFI/EFI/boot/bootaa64.efi /mnt/EFI/EFI/boot/bootaa64.efi.shim
mv /mnt/EFI/EFI/arch/grubaa64.efi /mnt/EFI/EFI/boot/bootaa64.efi
if cp /mnt/boot/grub/arm64-efi/core.efi /mnt/grubaa64.efi;then
sleep .01
else
return 17
fi
fi
if [ -e /mnt/EFI/EFI/boot/*.efi ];then
cp -rf /mnt/EFI/EFI/boot/*.efi /mnt
fi
openssl req -new -x509 -newkey rsa:4096 -days 365000 -keyout $tmpdir/jenux.key -out $tmpdir/jenux.crt -nodes -subj "/CN=Jenux ISO Secure Boot/"
openssl x509 -in $tmpdir/jenux.crt -out $tmpdir/jenux-iso.cer -outform DER
for f in `find /mnt -type f|grep vmlinuz`;do
mv $f $tmpdir/`basename $f`".unsigned"
sbsign --key $tmpdir/jenux.key --cert $tmpdir/jenux.crt --output $f $tmpdir/`basename $f`".unsigned"
rm $tmpdir/`basename $f`".unsigned"
done
for f in `find /mnt -type f|grep core.efi`;do
if file $f|grep -iw EFI|grep -iqw application;then
mv $f $f.unsigned
sbsign --key $tmpdir/jenux.key --cert $tmpdir/jenux.crt --output $f $f.unsigned
rm $f.unsigned
fi
done
for f in `find /mnt -type f|sed "/shim/d;/mm/d;/fb/d;/EFI\/boot/d"|grep .efi|sed /mod/d`;do
if file $f|grep -iw EFI|grep -iqw application;then
mv $f $f.unsigned
sbsign --key $tmpdir/jenux.key --cert $tmpdir/jenux.crt --output $f $f.unsigned
rm $f.unsigned
fi
done
mv $tmpdir/jenux-iso.cer /mnt/EFI
mv $tmpdir/jenux.crt /mnt/EFI/jenux.sbverify.crt
rm $tmpdir/jenux.key
if echo $prepbuilds|grep -iqw aarch64;then
cd /mnt/EFI
curl -Lo efi3.zip https://github.com/pftf/RPi3/releases/download/v1.39/RPi3_UEFI_Firmware_v1.39.zip
if yes|unzip -o efi3.zip;then
sleep .01
else
return 18
fi
rm efi3.zip Readme.md firmware/Readme.txt
mv config.txt config3.txt
mv RPI_EFI.fd RPI3_EFI.fd
sed -i "s|RPI_EFI.fd|RPI3_EFI.fd|g" config3.txt
curl -Lo efi4.zip https://github.com/pftf/RPi4/releases/download/v1.38/RPi4_UEFI_Firmware_v1.38.zip
if yes|unzip -o efi4.zip;then
sleep .01
else
return 19
fi
rm efi4.zip Readme.md firmware/Readme.txt
mv config.txt config4.txt
mv RPI_EFI.fd RPI4_EFI.fd
sed -i "s|RPI_EFI.fd|RPI4_EFI.fd|g" config4.txt
curl -Lo efi5.zip 'https://github.com/worproject/rpi5-uefi/releases/download/v0.3/RPi5_UEFI_Release_v0.3.zip'
if yes|unzip -o efi5.zip;then
sleep .01
else
return 20
fi
mv config.txt config5.txt
mv RPI_EFI.fd RPI5_EFI.fd
sed -i "s|RPI_EFI.fd|RPI5_EFI.fd|g" config5.txt
rm efi5.zip
echo \[pi3\] > config.txt
cat config3.txt >> config.txt
echo \[pi3+\] >> config.txt
cat config3.txt >> config.txt
rm config3.txt
echo \[pi4\] >> config.txt
cat config4.txt >> config.txt
echo \[pi400\] >> config.txt
cat config4.txt >> config.txt
echo \[cm4\] >> config.txt
cat config4.txt >> config.txt
echo \[cm4s\] >> config.txt
cat config4.txt >> config.txt
rm config4.txt
echo \[pi5\] >> config.txt
cat config5.txt >> config.txt
rm config5.txt
echo \[all\] >> config.txt
echo dtparam=audio=on >> config.txt
echo dtparam=krnbt=on >> config.txt
echo dtparam=pcie=on >> config.txt
sed -i "/dtoverlay=miniuart-bt/d" config.txt
dos2unix config.txt
cat > config.rpi.txt<<EOF
[pi3]
arm_64bit=1
[pi3+]
arm_64bit=1
[pi4]
arm_64bit=1
arm_boost=1
[pi400]
arm_64bit=1
arm_boost=1
[cm4]
arm_64bit=1
arm_boost=1
[pi400]
arm_64bit=1
arm_boost=1
[cm4]
arm_64bit=1
arm_boost=1
[cm4s]
arm_64bit=1
arm_boost=1
[pi5]
usb_max_current_enable=1
force_turbo=1
[all]
dtparam=audio=on
dtparam=krnbt=on
dtparam=pcie=on
initramfs archiso.img followkernel
EOF
cat > cmdline.rpi.txt<<EOF
archisolabel=${iso_label} archisobasedir=arch copytoram checksum
EOF
cp ${script_path}/${work_dir}/iso/arch/boot/${arch}/vmlinuz-linux.rpi kernel8.img
cp ${script_path}/${work_dir}/iso/arch/boot/${arch}/archiso.rpi.img archiso.img
cd $OLDPWD
fi
return 0
}
if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
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


if [ -z $arch ];then
export buildtype=tripple
export prepbuilds=`echo -en x86_64 i686 aarch64`
else
export buildtype=$arch
export prepbuilds=`echo -en $arch`
fi
for arch in `echo -en $prepbuilds`; do
run_once make_pacman_conf
run_once make_packages
run_once make_setup_mkinitcpio
run_once make_customize_airootfs
run_once make_boot
run_once make_boot_extra
run_once make_prepare
run_once make_efi
done


# Do all stuff for "iso"
run_once make_iso
cd "${script_path}/${out_dir}"
sha512sum "${iso_name}-${iso_version}-${buildtype}.enroler.iso" > "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.enroler.iso.sha512"
qemu-img convert -p -f raw -O vmdk "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.enroler.iso" "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.enroler.vmdk"
sha512sum "${iso_name}-${iso_version}-${buildtype}.enroler.vmdk" > "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.enroler.vmdk.sha512"
qemu-img convert -p -f raw -O vmdk "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.iso" "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.vmdk"
sha512sum "${iso_name}-${iso_version}-${buildtype}.vmdk" > "${script_path}/${out_dir}"/"${iso_name}-${iso_version}-${buildtype}.vmdk.sha512"
rm -rf ${work_dir} ${install_dir}
