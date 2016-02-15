# Setting up a PXE Server on Ubuntu

These instructions provide a detailed run-down of the what's and why's of creating a Ubuntu PXE server, for serving Ubuntu installers SPECIFICALLY. Each distro has its own little quirks and variations, so there's no real one-size-fits all, despite what many guides out there seem to try and do. Maybe it's just that distros have been gradually growing apart in their installers and kernel flavours. Maybe it's just untested recycled documentation.

There are still some things to smooth out as of writing (2016-02-13) but for the most part I'm nearly there.

I have decided to go into detail of the environment setup due to the immense pain I've had with other guides around the internet which tell you to do things without telling you why, with regard to your environment, what snippets are substitutable and which are not; and me ending up with non-working PXE systems with very little ability to troublehoot.

The final piece I need to solve now is how to configure the Kickstart file, or how to serve a preseed file instead.

These instructions should work for the most part though, and I'll be looking at automating as much of this as possible by way of a bash script so that, finally, a PXE server setup is just a few commands away. Once and for all.

## Test Environment

I did the deployment of the PXE server itself on a Ubuntu 14.04 server i386 in VirtualBox 4.3.34 ; and chose to deploy a Ubuntu 15.04 i386 ISO image arbitrarily.

For networking, you need NAT Network during PXE booting; you can use a NAT regular card so as to be able to pull from the internet. On the server, you can have one card as "NAT Network" and the other "NAT", but you will first have to edit `/etc/network/interfaces` and copy the eth0 settings to an eth1 configuration, then reboot.

If you switch a NIC between "NAT" and "NAT Network" or even "Bridged", you need to bring that network down and back up again, for example

	ifdown eth1
	ifup eth1

Use the IP address of the NAT Network for the DHCP configuration. Typically in VirtualBox this will be `10.0.3.*` or something.

## Firewall requirements

You SHOULD be doing this on an internal network so firewall security should not need to be too stringent. That being said if you want to be sure, you need to allow INPUT on at least port 69 (tftpd) and the file server port (80 for the example below, served over HTTP), and port 67 (DHCP); you will also need to allow ports 111 and 2049 for the NFS server.

Note that the IP `10.0.3.199` in this guide represents the IP of the PXE server we are configuring. Where encountered, replace it with the appropriate IP

If this is a VirtualBox VM, use a "NAT Network" adapter for testing with, and ensure that both the server and client use the same custom network (this is set up in the VBox main preferences). If you are using a different solution, you essentially need to ensure the two machines are on the same subnetwork.

Ensure that there are no other machines on the subnet, aside from your PXE server and its client during your preliminary tests.

## Install required packages

	apt-get install isc-dhcp-server tftp tftpd apache2 syslinux nfs-kernel-server

* The DHCP server allows the target PXE client to get an IP from our server specifically, and for the PXE server to advertise itself.

* TFTP is a lightweight implementation of a subset of FTP to allow minimal code to be implemented for embedded firmware, or that is what I understand. PXE boot specifically looks for TFTP, not regular FTP, so this is a requirement.

* Apache is being used to serve the Kickstart files. You can choose an alternative as required - for example, nginx, or a FTP server.

* NFS is selected here as the means by which we will be serving the installation files over the internal network. For some systems it is optional; for Ubuntu as the target OS to be installed, it is a requirement.

* `syslinux` contains a set of bootloaders, some of which we want for creating our setup. I forgot to document which problem this solved. Whoops.

## Configure DHCP

DHCP is used to provide the PXE boot instruction to the newly starting client machine.

Edit `/etc/dhcp/dhcpd.conf`

Add the following near the top; comment out any conflicting items in the file.

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
	subnet 10.0.3.0 netmask 255.255.255.0 {
		# this is a custom range, on the same subnet as your PXE server
		range 10.0.3.200 10.0.3.250;

		# our IP:
		option domain-name-servers 10.0.3.199;
		option domain-name "mydomain.home"; # just because, instructions.

		# client to route traffic via this pxe server
		option routers 10.0.3.199;
		default-lease-time 600;
		max-lease-time 7200;
		
		next-server 10.0.3.199;
		filename "pxelinux.0";
	}

## Setup TFTPd service via xinetd

Using xinetd because: all the existing guides out there specify to do so. With so many moving parts in this setup, I've followed this trend too. 

Edit `/etc/xinetd.d/tftp`

Change disabled option to "no", and set the `server_args` to `-s /tftpboot` (or other location desired)

If the file did not exist, simply create it with the following contents:

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

### Create the TFTP contents

	mkdir /tftpboot
	chmod 777 /tftpboot
	cp -v /usr/lib/syslinux/{pxelinux.0,menu.c32,memdisk,mboot.c32,chain.c32} /tftpboot
	mkdir /tftpboot/pxelinux.cfg
	mkdir /tftpboot/netboot

### Setup the NFS kernel server

Make a directory where you will mount the ISO, and specify its export.

	mkdir /srv/install

Edit /etc/exports and add the line:

	/srv/install   10.0.3.0/24(ro,async,no_root_squash,no_subtree_check) 

The export path MUST be a mountable node, so if you mount two ISOs, to `/srv/install/lubuntu` and `/srv/install/xubuntu` you MUST specify a line for each of them - it is not sufficient to just provide `/srv/install` on its own.

Start the kernel service

	service nfs-kernel-server start

## Get the DVD contents

You can either mount the DVD in-place

	mount -o mode=755 ./path/to/dvd/iso /srv/install

Or you can full-on copy the contents as appropriate

	mount -o mode=755 ./path/to/dvd.iso /mnt
	cp -rv /mnt/* /srv/install
	umount /mnt

Check that you have the `/mnt/dists` directory as provided by the DVD. If you do not, you will need to copy them through from the same architecture and release DVD for Ubuntu.

Not all Ubuntu distro copies have this - notably Ubuntu Server does not. Copy it from a desktop Ubuntu variant perhaps [ untested (2016-02-13) ]

## Get the boot kernel and image

Copy the boot images to `/tftpboot`

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
	nfs --server="10.0.3.199" --dir="/srv/install"

	bootloader --location=mbr
	zerombr
	clearpart --all --initlabel
	part swap --asprimary --fstype="swap" --size=1024
	part /boot --fstype xfs --size=200
	part pv.01 --size=1 --grow
	volgroup rootvg01 pv.01
	logvol / --fstype xfs --name=lv01 --vgname=rootvg01 --size=1 --grow
	rootpw --iscrypted $1$hw4S1wQ8$0GDzXkLWhlSQ.F8YsBO.n/ # TODO need to document how to generate this string

	%packages --nobase --ignoremissing
	@core
	%end

Ensure it can be read by the web server

	chmod a+r /var/www/html/ks/ubuntu1504x32.cfg

## Create a PXE boot menu

Edit `/tftpboot/pxelinux.cfg/default`

	default menu.c32
	prompt 0
	timeout 50
	ONTIMEOUT local
	MENU TITLE My PXE Menu
	
	LABEL ubuntu1504
	MENU LABEL Ubuntu 15.04
	KERNEL kernels15.04x32/vmlinuz
	APPEND initrd=kernels15.04x32/initrd.lz boot=casper only-ubiquity netboot=nfs nfsroot=10.0.3.199:/srv/install ks=http://10.0.3.199/ks/ubuntu1504x32.cfg

	LABEL local
	MENU LABEL Boot from Hard drive

The timeout is the number of _tenths_ of seconds to wait until timing out.

The final option, local, boots from the hard drive. Typically, it brings up the GRUB menu. You may need to configure the installed system's grub:

	sed -r -e 's/^(GRUB_TIMEOUT).+$/\1=1/' -i /etc/default/grub
	update-grub
	reboot

This wil cause the GRUB to timeout immediately and boot into the local system.

The kickstart option `ks=` does not currently work - working on it.

## Restart the services

Restart any services where you've made changes to the configuration files.

	service isc-dhcp-server restart
	service xinetd restart
	service nfs-kernel-server restart

If you want to make changes to `/srv/install` contents, it would be safest to stop the nfs-kernel-server service, as the service keeps open handles on the files.

# Configure the client

For VirtualBox, the following should be sufficient

* New VM
	* Create the VM with the desired specifications.
* System: Boot Order needs network turned on
	* For a physical machine, you may need to do this in the BIOS
* Network: same as the PXE server - either an internal network, or bridged

Now start the machine

* Start VM
* Cancel attach ISO

This should give us the option to start from the menu we defined earlier

Mission.... nearly complete.

# Troubleshooting

## Solved issues

These are issues I faced when testing which I resolved.

When the Ubuntu server installer encounters an error, you can see details on tty4

* If your machine does not boot from PXE, or complains that no boot medium is found, powercycle it. For some reason, sometimes the PXE broadcast is not detected - this could be a network interference, PXE server declares itself to the client via DHCP packets

* If you manage to get the PXE menu but it just repeats the countdown ad infinitam, check for typos in the boot menu `/tftpboot/pxelinux.cfg/default`

* If the installer complains about "Bad mirror" (can't find archive), check that you are indeed using the server's IP address not its name in the pxelinux.cfg menu file

* If the installer complains about "Bad mirror" (can't find archive), check that you have `/srv/install/ubuntu1504/dists/vivid/Release` (or trusty, precise, etc as appropriate)

* If you drop to a busybox shell/initramfs prompt on boot from image, or if you get a mount failure message in a loop, the initramfs image could not find the files (here served under NFS) - check addresses and paths in your menu config, and that the NFS server is running

## Known issues

* The current iteration of this document should get you to a fully working PXE boot, but the configuration of the Kickstart file needs tweaking, as it just lands us in the live session.

* I don't know how to add extra options to the kickstart file - not sure where it's properly documented, but I will find this out and send on

### Unresolved dead issues

* [obsolete - fix unknown] Boot from image from DVD fails with cannot find media at /dev/sr0; this is because the casper boot option expects something to be locally attached. The only way round this seems to be to use a kernel-nfs share that's properly configured, or to re-work the initrd image's scripts. In the Kickstart file, we've specified the URL, but that only takes effect after casper finishes starting itself up. Not sure there's any other way of having an HTTP link mounted at a filesystem at this point. Kernel NFS it is.

* [obsolete - see note] Ubuntu installation fails at "Install the system" step; from what I find on mailing lists, there's an issue with apt trying to get files from the repository under the "security" section (not included on the DVD), and so the installer bails. Need to deactivate this, or redirect this. -- DEPRECATED this was because I was using the kernel and image from mini.iso, which expects a ubuntu server image

