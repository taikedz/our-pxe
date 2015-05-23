#!/bin/sh

apt-get install brasero gksu zenity --assume-yes

mkdir /partimus
chmod a+rw /partimus

cat <<EOD > /home/$SUDO_USER/Desktop/SpinMe.desktop
# set up exectuable to run /root/our-pxe/bin/dtopspin.sh
EOD
