#!/bin/bash

[[ $UID != 0 ]] && {
	gksu $0 $(whoami)
	exit
}

respinlog=/root/respin.log
chmod a+r $respinlog

[[ 0 = zenity --question --title "Respin" --text "WARNING - we will now proceed to building the default system setup.\n\nDo you wish to proceed?" ]] && {
	cp /home/$1/{.config,.mozilla} /etc/skel >> $respinlog 2>&1

	hurs=/root/our-pxe/bin >> $respinlog 2>&1
	$hurs/hu-std.sh >> $respinlog 2>&1
	$hurs/school-apps.sh >> $respinlog 2>&1
	$hurs/isoprep.sh >> $respinlog 2>&1
	$hurs/respin.sh clean >> $respinlog 2>&1

	dtime=$(date +%F_%T | sed -r -e 's/(-|:)/./g' -e 's/_/-/')

	$hurs/respin.sh dist "partimus-$dtime.iso" >> $respinlog 2>&1

	su $1 -c "xdg-open /home/respin" &

	cp $respinglog /home/$1/respin-report.log
	zenity --text-info --title "Respin" --text "Your new installation CD image is ready."
}
