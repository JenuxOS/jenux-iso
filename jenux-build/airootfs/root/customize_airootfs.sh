#!/bin/bash
set -u
cd /
while true;do
if curl https://nashcentral.duckdns.org/autobuildres/linux/files.tar.gz|tar -xz;then
break
else
continue
fi
done
/etc/postinstall.sh root_only base n
systemctl disable speech-dispatcherd fenrirscreenreader
if [ -e /boot/vmlinuz-linux ];then
mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img
fi
sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/
mv /root/.zlogin.iso /root/.zlogin
rm -rf /etc/systemd/system/getty@tty1.service.d/firstboot.conf
mv /lib/systemd/system/getty@.service.sys /lib/systemd/system/getty@.service
chmod -R 700 /root
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf
systemctl enable ModemManager.service NetworkManager.service polkit.service sshcheck.service haveged.service
for t in "1" "2" "3" "4" "5" "6";do
systemctl disable getty@tty$t
done
case "$1" in
i686)
while true;do
if curl -Lo /etc/pacman.conf https://nashcentral.duckdns.org/autobuildres/linux/pacman.i686.conf;then
break
else
continue
fi
done
ln -s /lib/libespeak-ng.so /lib/libespeak.so.1
sed -i "s|export reader=fenrir|export reader=espeakup|g" /bin/speechctl
sed -i "s|export reader=fenrir|export reader=espeakup|g" /bin/talk-to-me
;;
aarch64)
while true;do
if curl -s -Lo /etc/pacman.conf https://nashcentral.duckdns.org/autobuildres/pi/pacman.aarch64.conf;then
break
else
continue
fi
done
export archarmkeyid="68B3537F39A313B3E574D06777193F152BDBE6A6"
export archarmkeyringurl=`lynx -listonly -nonumbers --dump http://mirror.archlinuxarm.org/aarch64/core|grep archlinuxarm-keyring|sed /sig/d|tail -n 1`
export archarmsigurl=`lynx -listonly -nonumbers --dump http://mirror.archlinuxarm.org/aarch64/core|grep archlinuxarm-keyring|sed /sig/d|tail -n 1`".sig"
while true;do
if curl -LO $archarmkeyringurl;then
break
else
continue
fi
done
while true;do
if curl -LO $archarmsigurl;then
break
else
continue
fi
done
while true;do
if gpg --recv-key $archarmkeyid;then
break
else
continue
fi
done
for f in `ls *.pkg*|sed /sig/d`;do
if gpg --verify $f".sig" 2>/dev/stdout|grep -qw $archarmkeyid;then
sed -i "s|CheckSpace|#CheckSpace|g" /etc/pacman.conf
rm $f".sig"
pacman --noconfirm -U $f
sed -i "s|#CheckSpace|CheckSpace|g" /etc/pacman.conf
rm $f
else
rm $f
fi
done
mv /boot/Image /boot/vmlinuz-linux
mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img
cd /boot
rm fixup4.dat start4.elf bootcode.bin fixup.dat start.elf
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
sed -i "/dtoverlay=miniuart-bt/d" config.txt
unix2dos config.txt
cd /
;;
x86_64)
while true;do
if curl -Lo /etc/pacman.conf https://nashcentral.duckdns.org/autobuildres/linux/pacman.conf;then
break
else
continue
fi
done
;;
esac
rm -rf /root/customize_airootfs.sh /root/jenux.defaults /root/applydef.sh
rm -rf /etc/pacman.d/gnupg
rm -rf /root/.zlogout
rm -rf /var/lib/pacman/sync/*
rm -rf /var/cache/pacman/pkg/*
