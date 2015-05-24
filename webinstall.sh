#!/bin/bash

# This script can be downloaded on its own to a Ubuntu system to automate the setup of the helpUse Partimus respin tool.

[[ $UID = 0 ]] || {
	sudo $0 $(whoami)
	exit 1
}

echo "Testing network connectivity ..."
ping -c 2 8.8.8.8 > /dev/null 2>&1
[[ $? = 1 ]] && {
	cat <<EOM

Could not get a network connection.

Please ensure you have internet connection, and try again.

You can run this program again later by typing in a comman line the folowing text:

	cd $(pwd)
	$0


EOM
	exit 2
}

apt-get update
apt-get install git gksu zenity brasero --assume-yes
cd /root
git clone https://github.com/taikedz/our-pxe

mkdir -p /partimus
cp /root/our-pxe/bin/dtopspin.sh /home/$SUDO_USER/.dtopspin.sh
chmod a+rwx /partimus
chmod a+rx /home/$SUDO_USER/.dtopspin.sh

spinme=/home/$SUDO_USER/Desktop/SpinMe.desktop

cat <<EOD > $spinme
[Desktop Entry]
Exec=/home/$SUDO_USER/.dtopspin.sh
Type=Application
Name=Make Partimus CD
Comment=helpUse/Partimus respin automator
EOD

chmod a+x $spinme
chown $SUDO_USER:$SUDO_USER $spinme
