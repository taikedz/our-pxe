# Setting up a PXE Server on Ubuntu

## Firewall requirements

You will be doing this on an internal network so firewall security shouldn't need to be too srtringent. That being said if you want to be sure, you need to allow INPUT on at least port 69 (tftpd) and the file server port (80 for the example below, served over HTTP), and port 67 (DHCP)

Note that the IP `192.168.1.199` represents the IP of the PXE server we are configuring. Where encountered, replace it with the appropriate IP

If this is a VM, you need to ensure this is on a Bridged adapter, so that other machines can see the VM directly. These notes presume you are using bridged.

## Install required packages

	apt install isc-dhcp-server tftp tftpd apache2 syslinux

The DHCP server allows the target PXE client to get an IP from our server specifically - not sure if this is a requirement for the PXE broadcast to be recognized...

TFTP is a lightweight implementation of a subset of FTP to allow minimal code to be implemented for embedded firmware, or that is what I understand. PXE boot specifically looks for TFTP, not regular FTP, so this is a requirement.

Apache is selected here as the means by which we will be serving the installation files over the internal network.

syslinux contains a set of bootloaders, some of which we want for creating our setup.

## Configure DHCP

Edit `/etc/dhcp/dhcp.conf`

Add the following near the top; comment out any conflicting items in the file.

	ddns-update-style interim;
	ignore client-updates;
	authoritative;
	allow booting;
	allow bootp;
	allow-unknown-clients;

	subnet 192.168.1.0 netmask 255.255.255.0 {
		range 192.168.1.200 192.168.1.250;
		 # our IP:
		option domain-name-servers 192.168.1.199;
		option domain-name "mydomain.home";
		# client to route traffic via this pxe server
		option routers 192.168.1.199;
		default-lease-time 600;
		max-lease-time 7200;
		
		next-server 192.168.1.199;
		filename "pxelinux.0";
	}

## Setup TFTPd service via xinetd

Edit `/etc/xinetd.d/tftp`

Change disabled option to "no", and set the server_args to `-s /tftpboot` (or other location desired)

If it does not exist, simply create it:

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

## Create the TFTP contents

	mkdir /tftpboot
	chmod 777 tftpboot
	cp -v /usr/lib/syslinux/{pxelinux.0,menu.c32,memdisk,mboot.c32,chain.c32} /tftpboot
	mkdir /tftpboot/pxelinux.cfg
	mkdir /tftpboot/netboot

## Get the DVD contents

Create a location in the web server for the distro

	mkdir /var/www/html/ubuntu15.04
	# for example.

You can either mount the DVD in-place

	mount -o loop ./path/to/dvd/iso /var/www/html/ubuntu15.04

Or you can full-on copy the contents as appropriate

	mount -o loop ./path/to/dvd.iso /mnt
	cp -rv /mnt/* /var/www/html/ubuntu15.04
	umount /mnt

Check that you have the `/mnt/dists` directory as provided by the DVD. If you do not, you will need to copy them through from the same architecture and release DVD for Ubuntu Server

## Get the network boot kernel and image

Copy the boot images to /tftpboot

	mkdir /tftpboot/kernels15.04x32
	cp /mnt/casper/vmlinuz /mnt/casper/initrd.lz /tftpboot/kernels15.04x32

## Make a kickstart file

This allows the unattended install of the system

	mkdir /var/www/html/ks
	vim /var/www/html/ks/ubuntu1504x32.cfg

Note - the URL must specify the IP address - using the server's network name will likely fail without extra DNS setup

	install
	lang en_GB.UTF-8
	keyboard uk
	timezone Europe/London
	auth --useshadow --enablemd5
	services --enabled=NetworkManager, sshd
	eula --agreed
	url --url="http://192.168.1.199/ubuntu15.04"

	bootloader --location=mbr
	zerombr
	clearpart --all --initlabel
	part swap --asprimary --fstype="swap" --size=1024
	part /boot --fstype xfs --size=200
	part pv.01 --size=1 --grow
	volgroup rootvg01 pv.01
	logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow
	rootpw --iscrypted $1$hw4S1wQ8$0GDzXkLWhlSQ.F8YsBO.n/

	%packages --nobase --ignoremissing
	@core
	%end

Ensure it can be read by the web server

	chmod a+r /var/www/html/ks/ubuntu1504x32.cfg

## Create a PXE boot menu

Edit `/tftpboot/pxelinux.cfg/default`

	default menu.c32
	prompt 0
	timeout 100
	MENU TITLE My PXE Menu
	
	LABEL ubuntu1504
	MENU LABEL Ubuntu 15.04
	KERNEL kernels15.04x32/vmlinuz
	APPEND initrd=kernels15.04x32/initrd.lz instrepo=http://192.168.1.199/ubuntu15.04 ks=http://192.168.1.199/ks/ubuntu1504x32.cfg boot=casper

## Restart the services

    service isc-dhcpd-server restart
    service xinetd restart

# Configure the client

For VirtualBox, the following should be sufficient

* New VM
	* Create the VM with the desired specifications.
* System: Boot Order needs network turned on
	* For a physical machine, you may need to do this in the BIOS
* Network: bridged

Now start the machine

* Start VM
* Cancel attach ISO

This should give us the option to start from the menu we defined earlier

This starts everything we wanted.... the installer is shown, but options are applied automatically

# Troubleshooting

## Solved issues

These are issues I faced when testing which I resolved.

When the Ubuntu server installer encounters an error, you can see details on tty4

* If your machine does not boot from PXE, or complains that no boot medium is found, powercycle it. For some reason, sometimes the PXE broadcast is not detected - this could be a network interference, but I'm not sure how the PXE server makes itself known to the client...

* If you manage to get the PXE menu but it just repeats the countdown ad infinitam, check for typos in the boot menu `/tftpboot/pxelinux.cfg/default`

* If the installer complains about "Bad mirror" (can't find archive), check that you are indeed using the server's IP address not its name

* If the installer complains about "Bad mirror" (can't find archive), check that you have `/var/www/html/ubuntu15.04/dists/vivid/Release` (or trusty, precise, etc as appropriate)

## Known issues

* Boot from image from DVD fails with cannot find media at /dev/sr0; this is because the casper boot option expects something to be locally attached. The only way round this seems to be to use a kernel-nfs share that's properly configured, or to re-work the initrd image's scripts. In the Kickstart file, we've specified the URL, but that only takes effect after casper finishes starting itself up. Not sure there's any other way of having an HTTP link mounted at a filesystem at this point. Kernel NFS it is.

* I don't know how to add extra options to the kickstart file - not sure where it's properly documented, but I will find this out and send on

* Ubuntu installation fails at "Install the system" step; from what I find on mailing lists, there's an issue with apt trying to get files from the repository under the "security" section (not included on the DVD), and so the installer bails. Need to deactivate this, or redirect this. -- DEPRECATED this was because I was using the kernel and image from mini.iso, which expects a ubuntu server image

