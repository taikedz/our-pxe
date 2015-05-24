#!/bin/bash

[[ $UID != 0 ]] && {
	# we need to do this here because the X session is not inherited
	[[ 0 = $(zenity --question --title="Respin" --text="WARNING - we will now proceed to building the default system setup.\n\nDo you wish to proceed?" ; echo $?) ]] && {
		$0 log
		gksudo $0 install
		zenity --info --title="Respin" --text="Your new installation CD image is ready."
	}
}

respinlog=/root/respin.log
touch $respinlog
chmod a+r $respinlog

# ======= Shims to open displays as thye user

[[ $1 = 'log' ]] && {
	x-terminal-emulator -c "tail -f $respinlog" &
}

#=======


[[ $1 = "install" ]] && {
	[[ ! -f /etc/respin/respin.version ]] && {
		dpkg -i "/root/our-pxe/respin_1.2.1/respin_1.2.1_all.deb"
	}

	# We copy the .mozilla configuration folder.
	# This script is only really to be used as per the accompanying instructions
	# NOT on your own long-in-the-tooth installation...!
	cp /home/$SUDO_USER/{.config,.mozilla} /etc/skel/ >> $respinlog 2>&1

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

	su $SUDO_USER -c "xdg-open /home/respin/respin" &

	cp $respinlog /home/$SUDO_USER/respin-report.log
}
