#!/bin/sh

[[ $UID != 0 ]] && {
	gksudo $0
	exit
}

apt-get install brasero gksu zenity --assume-yes

mkdir /partimus
chmod a+rw /partimus

spinme=/home/$SUDO_USER/Desktop/SpinMe.desktop

cat <<EOD > $spinme
[Desktop Entry]
Exec=/root/our-pxe/bin/dtopspin.sh
Terminal=false
Type=Application
Name=Respin
Comment=helpUse/Partimus respin automator
EOD

chmod a+x $spinme
chown $SUDO_USER:$SUDO_USER $spinme
