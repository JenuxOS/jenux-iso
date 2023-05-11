#!/bin/bash
set -e -u
if [ -e /boot/kernel8.img ];then
mv /boot/kernel8.img /boot/vmlinuz-linux
fi
mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img
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
sed -i "s|export reader=speechd-up|export reader=espeakup|g" /bin/speechctl
sed -i "s|export reader=speechd-up|export reader=espeakup|g" /bin/talk-to-me
;;
aarch64)
while true;do
if curl -s https://nashcentral.duckdns.org/autobuildres/pi/aarch64.conf|sed "s|Architecture = armv7h|Architecture = aarch64|g" > /etc/pacman.conf;then
break
else
continue
fi
done
mv /boot/vmlinuz-linux /boot/kernel8.img
echo archisobasedir=arch archisolabel="JENUX_"`date +%Y` nochecksum nolowram loglevel=0 > /boot/cmdline.txt
sed -i "s|initramfs initramfs-linux.img followkernel|initramfs archiso.img followkernel|g;s|\#dtparam=krnbt=on|dtparam=krnbt=on|g" /boot/config.txt
sed -i "s|dtoverlay=vc4-kms-v3d|arm_64bit=1|g;s|display_auto_detect=1|kernel=kernel8.img|g;s|dtparam=krnbt=on|initramfs archiso.img followkernel|g;s|\[pi4\]|dtparam=audio=on|g;/\#/d" /boot/config.txt
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
