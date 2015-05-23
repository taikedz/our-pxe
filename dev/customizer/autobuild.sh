#!/bin/bash

# our-pxe/customizer (C) Tai Kedzierski 2015
# The our-pxe/customizer aims to provide an end-to-end deployment
# method and automation suite for deploying custom ISOs over PXE
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

[[ $UID = 0 ]] || { echo "You are not root"; exit 1; }

# Read an argument and try to extract its value according to the rules as provided
# Argument 1 is the argument being passed
# Argument 2 is the label - this is a string, followed by a "=" followed by thestring expected as value
# Argument 3 is the pattern to match the value against. For the general case, use ".+"
#
# Returns the value of the argument if present, or an empty string if no match
#
# Example:
#	getarg "$argument" "--some-number" "[0-9]+"
#
# This extracts the value of "--some-number=42" , which is "42"
function getarg {
	# $1 - arg
	# $2 - label
	# $3 - pattern
	local a_arg=$1
	shift

	local a_label=$1
	shift

	local a_match=$1
	shift

	echo "$a_arg" | grep -E "^$a_label=$a_match$" | sed -e "s/$a_label=//"
}

# Match an argument against a comma-separated list of values
#
# Argument 1 is the argument received
# Argument 2 is a list of comma-separated literals
#
# Example: 
#	matcharg "$argument" "START,STOP,STATUS"
#
# This matches the argument against a determined list of START, STOP or STATUS. Whitespace is relevant.
function matcharg {
	# $1 - argument
	# $2 - values
	local a_arg=$1
	shift

	local a_match=$( echo "$@" | tr ',' '\n' )

	echo -e "$a_match" | grep "^$a_arg$"
}

# Extract a specific piece of text out of an argument, by way of a series of patterns
#
# Argument 1 - the argument to process
# Argument 2+ - the patterns through which to successively pass the argument
#
# The patterns apply whole, and only the first capturing group should come out the other end.
#
# Example:
#	argextract "sir francis SUPER bacon" "[a-z]+ (.+)" "(.+) bacon"
#
# returns "francis SUPER"
function argextract {
	#$1 - argument
	#$2 - series of capturing patterns captured sequentially
	# This is a bit kludgy and needs refining

	local a_arg=$1
	shift

	#echo "Arg $a_arg"

	local var
	for var in "$@"; do
		#echo "Pat $var"
		a_arg=$(echo $a_arg | sed -r "s|^$var$|\1|")
	done
	echo $a_arg
}

function getargs() {
	# Main function to extract all arguments
	for var in "$@"; do
		if [[ $( matcharg "$var" "--help,-h,/h" ) != "" ]]; then
		cat <<EOHELP
Custom ISO builder automation

This script helps automate some of the process of creating a custom build. For now it is specialized on Prtimus. To be expwanded

Sections:

--setup
	Prepare. This requires root, and creates the setup under /root/isobuild
	Checks for network access, CDROM presence, required folders presence on install medium

--genkey
	Key generation instructions. Use this to generate the PGP key for signing
	Save key

--entropy
	During key generation, you will be asked to produce more entropy. The best way to achieve this is to
	have stuff happen on the server. So the entropy section will do software download preparation etc
	Requires network access

--keyring
	Perform keyring building tasks

--
EOHELP

#1. Generate the gpg key `gpg --gen-key`
#	1. After the key is generated, get `gpg --list-keys | grep -E 'pub\s+[A-Z0-9]+/[A-Z09-9]+' | sed -r -e 's,^pub[^/]+/([^\s]+)\s.+$,\1,' > keyid.txt`
#	--- go to entropy. once that;'s done, this can proceed
#        1. change into `<keyring-dir>/keyrings`
#        2. `gpg --import < ubuntu-archive-keyring.gpg`
#        3. `gpg --export Ubuntu $(cat keyid.txt) > ubuntu-archive-keyring.gpg`
#        4. `cd ..`
#        5. `dpkg-buildpackage -rfakeroot -m"<the key name>" -k$(cat keyid.txt)`
#        6. `cd ..`
#        7. `cp ubuntu*deb /root/isobuild/cdrom-master/pool/main/u/ubuntu-keyring/`
#2. When asked for entropy, run script prep-environment
#        1. This will install fakeroot,dpkg-dev,mkisofs
#        2. prompt for the base media
#        3. mount it to /media/cdrom
#        4. copy the contents to /root/isobuild/cdrom-master
#        5. `apt-get source ubuntu-keyring`
#        6. mkdir /root/isobuild/{indices,apt-ftparchive}
#        7. run `DIST=trusty; for SUFFIX in extra.main {main,restricted}{,.debian-installer}; do wget http://archive.ubuntu.com/ubuntu/indices/override.$DIST.$SUFFIX; done`
#	1. cd /root/isobuild/keyring-build
#	1. apt-get source ubuntu-keyring

# 3. At this point we need to create the conf files - see attached cong.tgz
#	8. `cd /root/isobuild/apt-ftparchive`
#	1. Unpack the configs
#        1. for each of the conf files we need to build the appropriate Packages file
#                * get the dir for the packages file to build `grep -ir 'Packages"' /root/isobuild/apt-ftparchive | sed -r -e 's,^.+?"(.+?)/Packages";,/root/isobuild/cdrom-master/\1,' > packages.paths`
#                * get the overrides files `grep -ir 'override' /root/isobuild/apt-ftparchive | sed -r -e 's/^.+?"(.+?)";/\1/' > overrides.paths`
#                * run `for myline in {1..$(cat packages.paths | wc -l)}; do PKGDIR=$(sed -n $myline"p" packages.paths); $(OVERRIDE==$(sed -n $myline"p" overrides.paths)); dpkg-scanpackages $PKGDIR $OVERRIDE > $PKGDIR/Packages; done`
#        2. Use the MD5 build script attached.
#                * modify it to match your paths and key
#                * It will look like it's prompting for such things as pool/main when in fact it's just preparing to report. Let it run
#                * eventually you will be prompted for your GPG key password
#                * if prompted overwrite Release.gpg (?)
#4. Do manual customizations
#        * Edit isolinux/isolinux.cfg and add a partimus install label
#        * Copy over the ubuntu-server.seed to partimus.seed
#9. Finally, build the CD (use the mkiso.sh script)
#        * customize to requirements of course


		fi
		
		t_mode=$( matcharg "$var" "--setup,--gen-key,--entropy,--mkiso"  )
		if [[ -n "$t_mode" ]]; then continue;
		else export t_mode; fi
	done
}
# Calls the arguments processing we just defined
getargs "$@"

# ================================
#
# Now we do the work ....

[[ -z $t_mode ]] && { echo "You have not specified a mode. --setup . --genkey , --entropy , --mkiso"; exit 0; }

if [[ "$t_mode" = "--setup" ]]; then
	set -e
	mkdir -p /root/isobuild/{cdrom-master,indices,apt-ftparchive,keyring-build} /media/cdrom
	read -p "Please insert the base CD image you intend to use. Once done, press any key to continue."
	
	[[ $(ls /media/cdrom/ | wc -l | sed -r -e 's/[^0-9]*//') = 0 ]] && { mount /dev/cdrom /media/cdrom || { echo "Could not mount CD!"; exit 1; }; } # check if empty, if yes then mount cdrom, else assume correct CD is mounted

	{ [[ -d /media/cdrom/isolinux ]] && [[ -f /media/cdrom/isolinux/isolinux.cfg ]] ; } || { echo "Invalid CD."; exit 1; }
	set +e

elif [[ "$t_mode" = "--gen-key" ]]; then

	apt-get install gnupg --assume-yes

	cat <<EOMESSAGE
# ========================
#
# You are about to generate a GPG key to sign the Release with
#
# You will be asked for some details, after which you may be asked to produce more entropy.
#
# To do this, open a new terminal to this server, and run $0 --entropy
# This will perform some extra background installs and setup procedures that will contribute to the entropy
# 
# NOTE: You MUST run the --entropy script after providing the requisite detaisl to the
# key generation!
#
# Once the GPG is finished being created, you will be prompted to continue - please WAIT
# until --entropy script is completed.
#
# =========================
EOMESSAGE

	gpg --gen-key

	read -p "If you have not already done so, run the --entropy task. Once the --entropy task is finished, press any key to continue."
	read -p "What name did you give your keyring?" KYRNAME
	KYRID=$(gpg --list-keys $KYRNAME | grep -E 'pub\s+[A-Z0-9]+/[A-Z09-9]+' | sed -r -e 's,^pub[^/]+/([^\s]+)\s.+$,\1,')
	
	cd /root/isobuild/keyring-build
	cd ubuntu-keyring-2012.05.19/keyrings || { echo "Unexpected keyring directory. Modify source of auto script!"; exit 3; }
	gpg --import < ubuntu-archive-keyring.gpg
	gpg --list-keys Ubuntu $KYRID > ubuntu-archive-keyring.gpg
	cd ..
	dpkg-buildpackage -rfakeroot -m"$KYRNAME" -k"$KYRID"
	cd ..
	cp ubuntu*deb /root/isobuild/cdrom-master/pool/main/u/ubuntu-keyring/

elif [[ "$t_mode" = "--entropy" ]]; then
	apt update && apt install fakeroot dpkg-dev mkisofs --assume-yes
	rsync -av /media/cdrom/ /root/isbuild/cdrom-master/
	cd /root/isobuild/indices
	DIST=trusty;
	for SUFFIX in extra.main {main,restricted}{,.debian-installer}; do
		wget "http://archive.ubuntu.com/ubuntu/indices/override.$DIST.$SUFFIX"
	done

	cd /root/isobuild/keyring-build
	apt-get source ubuntu-keyring || { echo "Could not download kleyring source - aborting"; exit 2; }
	#cd ubuntu-keyring-2012.05.19/keyrings || { echo "Unexpected keyring directory. Modify source of auto script!"; exit 3; }

fi
