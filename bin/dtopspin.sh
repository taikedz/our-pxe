#!/bin/bash

respinlog=/var/log/respin.log

[[ $UID != 0 ]] && {
	# we need to do this here because the X session is not inherited
	[[ 0 = $(zenity --question --title="Respin" --text="WARNING - we will now proceed to building the default system setup.\n\nDo you wish to proceed?" ; echo $?) ]] && {
		x-terminal-emulator -e "tail -n 0 -f $respinlog" &
		gksudo $0 install $(whoami)
		xdg-open /home/respin/respin &

		zenity --info --title="Respin" --text="Your new installation CD image is ready."
	}
}


#=======


[[ $1 = "install" ]] && {
	[[ ! -f /etc/respin/respin.version ]] && {
		dpkg -i "/root/our-pxe/respin_1.2.1/respin_1.2.1_all.deb"
	}
	SUDO_USER=$2

	# We copy the .mozilla configuration folder.
	# This script is only really to be used as per the accompanying instructions
	# NOT on your own long-in-the-tooth installation...!
	cp -rv /home/$SUDO_USER/{.config,.mozilla} /etc/skel/ >> $respinlog 2>&1
	rm /etc/skel/.config/user-dirs.{dirs,locale}

	# Update in case the user doesn't know to
	apt-get update >> $respinlog 2>&1

	# Home location of this script - we assume installed as recommended in setup.sh
	hurs=/root/our-pxe/bin >> $respinlog 2>&1

	# Install my packages
	$hurs/hu-std.sh >> $respinlog 2>&1
	$hurs/school-apps.sh >> $respinlog 2>&1

	# Install the requirememnts for respin.sh
	$hurs/isoprep.sh >> $respinlog 2>&1

	# Clean up - in case this is not the first time we ran this
	$hurs/respin.sh clean >> $respinlog 2>&1

	# Create that ISO!
	dtime=$(date +%F_%T | sed -r -e 's/(-|:)/./g' -e 's/_/-/')
	$hurs/respin.sh dist "partimus-$dtime.iso" >> $respinlog 2>&1

	cp $respinlog /home/$SUDO_USER/respin-report.log
}
