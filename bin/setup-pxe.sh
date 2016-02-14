#!/bin/bash

# ==== Variables for script

set -u # fail on undeclared variable

SERVERIP=
IPBASE=
NETMASK=255.255.255.0
RANGELO=
RANGEHI=

ISOFILE=
DISTRO=
DSLUG=

VERBOSE=no
ISOMODE=mount # copy or mount iso contents?

# ===========================================

ippat='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
function validip {
	[[ ! "$1" =~ $ippat ]] && return 1
	for x in $(echo "$1"|sed 's/./ /'); do
		[[ "$x" -gt 255 ]] && return 1
	done
	return 0
}

function distroslug {
	echo "$@" | sed -r 's/[^a-zA-Z0-9._-]+/-/g'
}

function debuge {
	[[ "$VERBOSE" = yes ]] && echo -e "\033[0;36m$@\033[0m"
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
	shift
	;;
-ip)
	SERVERIP="$1"
	shift
	;;
-lo)
	RANGELO="$1"
	shift
	;;
-hi)
	RANGEHI="$1"
	shift
	;;
-distro)
	DISTRO="$1"
	shift
	;;
-iso)
	ISOFILE="$1"
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

cat <<EOF
SERVERIP=$SERVERIP
IPBASE=$IPBASE
NETMASK=$NETMASK
RANGELO=$RANGELO
RANGEHI=$RANGEHI
DISTRO=$DISTO
EOF

exit
# =============

debuge "Install required packages"
apt-get install isc-dhcp-server tftp tftpd apache2 syslinux nfs-kernel-server --assume-yes

# =============
debuge "Dns setup"
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
debuge "NFS kernerl server setup"

mkdir /srv/install
echo "/srv/install   ${IPBASE}.0/24(ro,async,no_root_squash,no_subtree_check)" >> /etc/exports

service nfs-kernel-server start

# ==============
debuge "Get DVD contents"

if [[ "$ISOMODE" = mount ]]; then
	debuge "ISO mode: mount"
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
