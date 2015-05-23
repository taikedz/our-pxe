#!/bin/bash

[[ $UID = 0 ]] || {
	gksudo $0
	exit
}

apt-get install brasero gksu zenity --assume-yes

mkdir -p /partimus
ln -s /root/our-pxe/bin/dtopspin.sh /home/partimus/.dtopspin.sh
chmod -R a+rw /partimus
chmod a+rx /home/partimus/.dtopspin.sh

spinme=/home/$SUDO_USER/Desktop/SpinMe.desktop

cat <<EOD > $spinme
[Desktop Entry]
Exec=/home/partimus/.dtopspin.sh
Terminal=false
Type=Application
Name=Respin
Comment=helpUse/Partimus respin automator
EOD

chmod a+x $spinme
chown $SUDO_USER:$SUDO_USER $spinme
