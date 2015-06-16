The following are preliminary notes for setting up a PXE boot server on CentOS

There are some additional notes for pushing UBuntu images as well, but they are incomplete and my testing has shown Ubuntu booting to have problems - it successfully finds the image, starts the installation task, but then the installer encounters and error.

I suspect an error in the "mini.iso" image

# Server

VM with network bridged and promiscuous=allow all

Required packages

* DHCP
* tftp
* syslinux
* vsftpd

## Network setup


	nmtui # we set up the IP manually

Edit connection

set to manual
just use the same IP address, and set ourself to be the DHCP. For this example, the PXE ip address is 192.168.1.199/24
gateway and DNS server should be the normal gateway and server (your router)

	systemctl restart network

Note - this is so that we can inform the scripts created below of a fixed IP. By doing a "rebuild" script that re-creates them with current network settings, and runs on machine boot, all should be taken care of..... right?

## Turn off security

Now turn off selinux and the firewall (I should really tailor this)

	/etc/selinux/config -- disable
	systemctl stop firewalld
	systemctl disable firewalld
	reboot

We've turned off the firewall.... is this really a good idea? Note that TFTPD listens on well-known port 69 and could simply leave this one open

Others to leave open include DHCP, and the ports for the file server

## Install required packages

	yum -y install dhcp tftp tftp-server syslinux wget vsftpd

This guide uses vsftpd - but we could use any resource transfer protocol accessible via URI - Apache web server for example

# Configure DHCP

Indicative settings.


	vim /etc/dhcp/dhcp.conf

		ddns-update-style interim;
		ignore client-updates;
		authoritative;
		allow booting;
		allow bootp;
		allow-unknown-clients;

		subnet 192.168.1.0 netmask 255.255.255.0 {
			range 192.168.1.200 192.168.1.250;
			option domain-name-servers 192.168.1.199; # our IP
			option domain-name "mydomain.home";
			option routers 192.168.1.199 # client to route traffic via this pxe server
			default-lease-time 600;
			max-lease-time 7200;
			
			next-server 192.168.1.199;
			filename "pxelinux.0";
		}


setup tftpd with xinetd server supervisor

and copy in resources for net-booting (net-grub, if you will)

tftpd is a very lighhtweight FTP server geared towards network booting

it does not need to be constantly up and uses its own port it seems....

	vim /etc/xinetd.d/tftp

Change disabled option to "no"

Set server_args to `-s /tftpboot` (or other location desired)


	mkdir /tftpboot
	chmod 777 tftpboot
	cp -v /usr/share/syslinux/{pxelinux.0,menu.32,memdisk,mboot.c32,chain.c32} /tftpboot
	mkdir /tftpboot/pxelinux.cfg
	mkdir /tftpboot/netboot

## Copy the DVD files

Mount the DVD of the target system to install
then copy its contents to the public main FTP directory

	mount -o loop ./path/to/dvd.iso /mnt
	cp -rv /mnt/* /var/ftp/pub

### For Lubuntu

You will also need to copy the `$iso/dists/` directory from off the Ubuntu Server DVD of same release and architecture.

## Grab the kernel and image for the live boot environment

#### For CentOS

	cp /mnt/images/pxeboot/{vmlinuz,initrd.img} /tftpboot/netboot

### For Ubuntu

For ubuntus you want the vmlinuz and initrd files from mini.iso corresponding to your distribution. See the Ubuntu website, download the mini.iso from there.

https://help.ubuntu.com/community/Installation/MinimalCD

It needs to be the matching release and architecture as your target PXE Ubuntu

### Both

Then generate a root password for the system

	openssl passwd -1 target-root-password > /root/password

## Create a Kickstart file

Make the kickstart file for the target system

The following is likely CentOS specific

Edit `/var/ftp/pub/ks.cfg` and add these lines:

        install
        lang en_GB.UTF-8
        keyboard uk
        timezone Europe/London
        auth --useshadow --enablemd5
        selinux --disabled
        firewall --disabled
        services --enabled=NetworkManager, sshd
        eula --agreed
        #FTP location
        url --url="ftp://192.168.1.132/pub/"

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

# Create PXE boot menu

Edit `/tftpboot/pxelinux.cfg/default`

        default menu.c32
        prompt 0
        timeout 100
        MENU TITLE My PXE Menu
        
        LABEL centos7_x64
        MENU LABEL CentOS 7 x64
        KERNEL netboot/vmlinuz
        APPEND initrd=netboot/initrd.img instrepo=ftp://192.168.1.199/pub ks=ftp://192.168.1.199/pub/ks.cfg

For ubuntus you need "APPEND" line to also have "boot=casper"

## Start all services

	systemctl enable dhcpd
	systemctl enable xinetd
	systemctl enable vsftpd
	systemctl restart dhcpd
	systemctl restart xinetd
	systemctl restart vsftpd


This concludes the server setup

# Client

New VM

System: Boot Order needs network turned on
Network: bridged, promiscuous=allow all, use adapter type Pro Server (why??)

Start VM. Cancel attach ISO

This should give us the option to start from the menu we defined earlier

This starts everything we wanted.... the installer is shown, but options are applied automatically

