#!/bin/bash
set -e -u
if [ -e /boot/vmlinuz-linux ];then
mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img
fi
sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
locale-gen
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
usermod -s /usr/bin/zsh root
cp -aT /etc/skel/ /root/
chmod 700 /root
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
if [ -e /etc/pacman.d/blackarch-mirrorlist ];then
sed -i "s/# Server/Server/g" /etc/pacman.d/blackarch-mirrorlist
fi
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf
systemctl enable NetworkManager.service polkit.service sshcheck.service wifiinit.service haveged.service
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
mv /boot/Image /boot/vmlinuz-linux
mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img
cd /boot
rm fixup4.dat start4.elf bootcode.bin fixup.dat start.elf
curl -Lo efi4.zip https://github.com/pftf/RPi4/releases/download/v1.35/RPi4_UEFI_Firmware_v1.35.zip
unzip efi4.zip
rm efi4.zip Readme.md firmware/Readme.txt
mv config.txt config4.txt
mv RPI_EFI.fd RPI4_EFI.fd
sed -i "s|RPI_EFI.fd|RPI4_EFI.fd|g" config4.txt
curl -Lo efi3.zip https://github.com/pftf/RPi3/releases/download/v1.39/RPi3_UEFI_Firmware_v1.39.zip
unzip efi3.zip
rm efi3.zip Readme.md firmware/Readme.txt
mv config.txt config3.txt
mv RPI_EFI.fd RPI3_EFI.fd
sed -i "s|RPI_EFI.fd|RPI3_EFI.fd|g" config3.txt
echo \[pi3\] > config.txt
cat config3.txt >> config.txt
rm config3.txt
echo \[pi4\] >> config.txt
cat config4.txt >> config.txt
rm config4.txt
echo \[all\] >> config.txt
echo dtparam=audio=on >> config.txt
echo dtparam=krnbt=on >> config.txt
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
pacman -Q > /pkg
rm -rf /root/customize_airootfs.sh
rm -rf /var/lib/pacman/sync/*
rm -rf /var/cache/pacman/pkg/*
