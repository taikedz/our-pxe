#!/bin/sh

[[ $UID != 0 ]] && {
	gksudo $0
	exit
}

apt-get install brasero gksu zenity --assume-yes

mkdir /partimus
chmod a+rw /partimus

cat <<EOD > /home/$SUDO_USER/Desktop/SpinMe.desktop
[Desktop Entry]
Exec=/root/our-pxe/bin/dtopspin.sh
Terminal=false
Type=Application
Name=Respin
Comment=helpUse/Partimus respin automator
# set up exectuable to run /root/our-pxe/bin/dtopspin.sh
EOD
