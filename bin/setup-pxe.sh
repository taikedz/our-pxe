#!/bin/bash

# ==== Variables for script

set -u # fail on undeclared variable

SERVERIP=
IPBASE=
NETMASK=255.255.255.0
RANGELO=
RANGEHI=

ROOTPASS='$1$hw4S1wQ8$0GDzXkLWhlSQ.F8YsBO.n/' # need to custom-generate this interactively

ISOFILE=
DISTRO=
DSLUG=

KERNEL=
BOOTIMG=

VERBOSE=no
ISOMODE=mount # copy or mount iso contents?

# ===========================================

function printhelp {
cat <<EOHELP

$(basename $0) -distro DISTRONAME -iso PATH

Parameters

Required
	-distro "Distro Name"
		Pretty name of Distro

	-iso PATH
		Path to ISO file to serve

Optional

	-netmask NETMASK
		specify the network mask
		default: 255.255.255.0

	-ip IPADDR
		specify the IP of the current server
		default: first non-localhost address found via ifconfig listing

	-lo IPADDR
		lower of range of IP space for DHCP
		default: using the IPADDR, x.x.x.1

	-hi IPADDR
		higher of range of IP space for DHCP
		default: using the IPADDR, x.x.x.255

Mode switches

	--iso-mount
		Causes the ISO contents simply to be mounted
		
	--isocopy
		Causes the ISO contents to be copied to local disk

	--verbose
		Enable verbose/debug mode

	--help
		Prints this help
EOHELP
}

ippat='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
function validip {
	[[ ! "$1" =~ $ippat ]] && return 1
	for x in $(echo "$1"|sed 's/\./ /g'); do
		[[ "$x" -gt 255 ]] && { echo "no"; return 1; }
	done
	echo "yes"
	return 0 # why does this not work?
}

function distroslug {
	echo "$@" | sed -r -e 's/[^a-zA-Z0-9._-]+/-/g' -e 's/\.iso$//'
}

function debuge {
	if [[ "$VERBOSE" = yes ]]; then
		echo -e "\033[0;36m$@\033[0m"
	fi
}

function warne {
	echo -e "\033[1;33m$@\033[0m"
}

function faile {
	echo -e "\033[1;31m$@\033[0m"
}

while [[ -n "$@" ]]; do
ARG=$1 ; shift

case "$ARG" in
-netmask)
	NETMASK="$1"
	if [[ $(validip "$1") != yes ]]; then
		faile "Invalid network mask: $1"
		exit 2
	fi
	shift
	;;
-ip)
	SERVERIP="$1"
	if [[ $(validip "$1") != yes ]]; then
		faile "Invalid server IP: $1"
		exit 2
	fi
	shift
	;;
-lo)
	RANGELO="$1"
	if [[ $(validip "$1") != yes ]]; then
		faile "Invalid lower range: $1"
		exit 2
	fi
	shift
	;;
-hi)
	RANGEHI="$1"
	if [[ $(validip "$1") != yes ]]; then
		faile "Invalid upper range: $1"
		exit 2
	fi
	shift
	;;
-distro)
	DISTRO="$1"
	shift
	;;
-iso)
	ISOFILE="$1"
	if [[ ! -f "$1" ]]; then
		faile "Not a file: $1"
		exit 3
	fi
	DSLUG=$(distroslug $(basename "$ISOFILE"))
	shift
	;;

# Mode switches
--verbose)
	VERBOSE=yes
	;;
--iso-copy)
	ISOMODE=copy
	;;
--iso-mount)
	ISOMODE=mount
	;;
--help)
	printhelp
	exit 0
	;;
esac
done

if [[ -z "$SERVERIP" ]]; then
	SERVERIP=$(ifconfig |egrep -o 'inet addr:\S+'|grep -v '127.0.0.1'|head -n 1|sed -r -e 's/inet addr://')
fi

IPBASE=$(echo "$SERVERIP"|sed -r -e 's/\.[0-9]+$//')

if [[ -z "$RANGEHI" ]] || [[ -z "$RANGELO" ]]; then
	RANGELO="$IPBASE".1
	RANGEHI="$IPBASE".255
fi


if [[ -z "$DISTRO" ]] || [[ -z "$ISOFILE" ]]; then
	faile "You need to specify a Distro name and an ISO file"
	exit 1
fi

cat <<EOF
Here is a summary of what will be installed:

SERVERIP=$SERVERIP
IPBASE=$IPBASE
NETMASK=$NETMASK
RANGELO=$RANGELO
RANGEHI=$RANGEHI
DISTRO=$DISTRO
EOF

read -p "Continue ? yes/NO> "

if [[ "$REPLY" != yes ]]; then
	faile "Answer not 'yes' -- aborting."
	exit 127
fi

# =============

debuge "Install required packages"
apt-get install isc-dhcp-server tftp tftpd apache2 syslinux nfs-kernel-server --assume-yes

# =============
debuge "DNS setup"
mv /etc/dhcp/dhcpd.conf{,.bak}

dbuge "$(ls /etc/dhcp)"
cat <<EOF >> /etc/dhcp/dhcpd.conf
ddns-update-style interim;
ignore client-updates;
authoritative;
allow booting;
allow bootp;
allow-unknown-clients;

# the subnet needs to refer to the appropriate IP family
# typically if your ip is of the form a.b.c.d
# the subnet woudl likely be a.b.c.0 - specifically the zero
# with a subnet mask of 255.255.255.0
subnet ${IPBASE}.0 netmask ${NETMASK} {
	# this is a custom range, on the same subnet as your PXE server
	range ${RANGELO} ${RANGEHI};

	# our IP:
	option domain-name-servers ${SERVERIP};
	option domain-name "mydomain.home"; # just because, instructions.

	# client to route traffic via this pxe server
	option routers ${SERVERIP};
	default-lease-time 600;
	max-lease-time 7200;

	next-server ${SERVERIP};
	filename "pxelinux.0";
}
EOF

grep -v "ddns-update-style" /etc/dhcp/dhcpd.conf.bak >> /etc/dhcp/dhcpd.conf

# ================
debuge "Setup TFTPd via xinetd"

if [[ -f /etc/xinetd.d/tftp ]]; then
	debuge "backup old tftp file"
	mv /etc/xinetd.d/tftp{,.bkp}
	debuge "$(ls /etc/xinet.d)"
fi

cat <<EOF > /etc/xinetd.d/tftp
# default: off
# description: The tftp server serves files using the Trivial File Transfer
#    Protocol.  The tftp protocol is often used to boot diskless
#    workstations, download configuration files to network-aware printers,
#    and to start the installation process for some operating systems.
service tftp
{
	socket_type     = dgram
	protocol        = udp
	wait            = yes
	user            = root
	server          = /usr/sbin/in.tftpd
	server_args     = -s /tftpboot
	disable         = no
}

EOF

debuge "Create tftpboot, copy files from /usr/lib/syslinux"
mkdir /tftpboot
chmod 777 /tftpboot
cp -v /usr/lib/syslinux/{pxelinux.0,menu.c32,memdisk,mboot.c32,chain.c32} /tftpboot
mkdir /tftpboot/pxelinux.cfg
mkdir /tftpboot/netboot

# ==============
debuge "NFS kernel server setup"

mkdir /srv/install
echo "/srv/install   ${IPBASE}.0/24(ro,async,no_root_squash,no_subtree_check)" >> /etc/exports

# TODO adapt for systemd
service nfs-kernel-server start

# ==============
debuge "Get DVD contents"

if [[ "$ISOMODE" = mount ]]; then
	debuge "ISO mode: mount"
	mkdir "/srv/install/$DSLUG"
	mount -o loop "$ISOFILE" "/srv/install/$DSLUG"
else
	debuge "ISO mode: copy"
	mkdir "/mnt/$DSLUG"
	mount -o loop "$ISOFILE" "/mnt/$DSLUG"
	cp -R "/mnt/$DSLUG" "/srv/install/$DSLUG"
	umountu "/mnt/$DSLUG"
	rmdir "$/mnt/$DSLUG"
fi

if [[ ! -d "/srv/install/$DSLUG/dists" ]]; then
	warne "You do not have the '/dists' directory in your install folder; Ubuntu installation may fail"
fi

# ==============
debuge "Get kernel and initrd image"

mkdir "/tftpboot/$DSLUG"
KERNEL=$(basename $(ls /srv/install/$DSLUG/vmlinu*))
BOOTIMG=$(basename $(ls /srv/install/$DSLUG/initrd*))
cp /srv/install/$DSLUG/$KERNEL /srv/install/$DSLUG/$BOOTIMG "/tftpboot/$DSLUG"

# ==============
debuge "Make kickstart file"

mkdir /var/www/html/ks

cat <<EOKSFILE > /var/www/html/ks/"$DSLUG".ks
install
lang en_GB.UTF-8
keyboard uk
timezone Europe/London
auth --useshadow --enablemd5
services --enabled=NetworkManager, sshd
eula --agreed
nfs --server="$SERVERIP" --dir="/srv/install"

bootloader --location=mbr
zerombr
clearpart --all --initlabel
part swap --asprimary --fstype="swap" --size=1024
part /boot --fstype xfs --size=200
part pv.01 --size=1 --grow
volgroup rootvg01 pv.01
logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow
rootpw --iscrypted $ROOTPASS

%packages --nobase --ignoremissing
@core
%end

EOKSFILE

chmod a+r /var/www/html/ks/"$DSLUG".ks

# ==============
debuge "Create PXE boot menu"

cat << EOMENU > /tftpboot/pxelinux.cfg/default
default menu.c32
prompt 0
timeout 100
MENU TITLE PXE Start

LABEL $DSLUG
MENU LABEL $DISTRO
KERNEL $DSLUG/$KERNEL
APPEND initrd=$DSLUG/$BOOTIMG boot=casper netboot=nfs nfsroot=$SERVERIP:/srv/install ks=http://$SERVERIP/ks/${DSLUG}.ks

EOMENU

# =============

debuge "Restart services"
# TODO - adapt for systemd

service isc-dhcp-server restart
service xinetd restart
service nfs-kernel-server restart
