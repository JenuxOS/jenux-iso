clear
talk-to-me
setopt singlelinezle
~/.automated_script.sh
autoload -Uz promptinit
prompt grml-large
alias ls="ls -A1 --sort=version"
if cat /proc/cmdline|grep -q nokeyrings;then
sleep .01
else
if [ -e /etc/pacman.d/gnupg ];then
sleep .01
else
echo initializing keyrings for package manager signature checking
while true;do
if rm -rf /etc/pacman.d/gnupg > /dev/null 2>/dev/null;pacman-key --config /etc/pacman.conf --gpgdir /etc/pacman.d/gnupg --init > /dev/null 2>/dev/null;pacman-key --config /etc/pacman.conf --gpgdir /etc/pacman.d/gnupg --populate `ls /usr/share/pacman/keyrings/*.gpg|sed "s|\/usr\/share\/pacman\/keyrings\/||g;s|\\.gpg||g"|tr \\\n \  ` > /dev/null 2>/dev/null;then
break
else
continue
fi
done
fi
fi
export mytty=`basename $TTY`
if [ -e ~/postlogin ];then
if [ -e ~/.postlogin.$mytty ];then
true
echo -n > ~/.postlogin.$mytty
else
~/postlogin
rm ~/postlogin
echo -n > ~/.postlogin.$mytty
fi
else
echo -n > ~/.postlogin.$mytty
fi
if [ -e ~/unattend ];then
if [ -e ~/.unattend.$mytty ];then
true
else
export product=`cat ~/unattend|head -n 1|cut -f 2 -d \#`
case "$product" in
android)
echo -n > ~/.unattend.$mytty
androidbuild
;;
jenux)
echo -n > ~/.unattend.$mytty
autobuild
;;
nbd)
echo -n > ~/.unattend.$mytty
export IFS=$(echo -en \\n\\b)
for n in `cat ~/unattend|sed "/#nbd/d"`;do
tgtdisk $n&
sleep 1
done
echo target disks ready, check console for uris
while true;do
read var
done
;;
pi)
echo -n > ~/.unattend.$mytty
pibuild
;;
remote)
echo -n > ~/.unattend.$mytty
;;
*)
echo -n > ~/.unattend.$mytty
echo unsupported unattend for $product. Please press enter to load main menu
read var
;;
esac
rm ~/unattend
fi
else
echo -n > ~/.unattend.$mytty
fi
for t in "2" "3" "4" "5" "6" "S0" "S1" "S2" "S3";do
systemctl start getty@tty$t
done
automenu
logout
