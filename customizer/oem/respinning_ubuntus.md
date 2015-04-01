# Using Remastersys/respin to create a custom ISO

The following notes are regarding creating a custom install CD for an Ubuntu-based system, with as little time spent at command line as possible.

I will flesh it out into a fuller guide in time, and include a base image with extra scripts to reduce even further the need to use the command line in future.

This CD customization procedure will eventually be aimed at non-technical persons themselves.

Tai -- 2015/03/29

# Pre requisites

Recommended hardware / spec for VM guest

* 1 GB RAM
* Single core CPU @ 1.8 GHz+
* 25 GB drive

Recommended hardware for host of VM

* 2 GB RAM (and nothing else running)
* dual core CPU @ 1.8 GHz
* 100 GB free space

# 1/ Get Ubuntu

Download the Ubuntu ISO for the system you want to install

Start your PC or virtual machine (VM) with the ISO / CD

Proceed through the installation as normal, choosing appropriate options. These will be applied to the end system that you will get.

# 2/ Set up customizations

Restart the installed system

You can now install software and change global configurations, but the profile you will be using will not be carried over to the target install - only changes to the "root" account will be preserved.

To affect individual users' accounts, you will need to edit the /etc/skel directories.

Proceed to installing the software you need.

(If you are using VirtualBox, you may first want to install gcc + make, install VB addons, and reboot; then uninstall gc + make)

Recommended base set of software for maintainers:

	vim git zenity geany gksu gitso

* vim is a better text editor for the command line - useful for when a system admin needs to do work, especially if they are connected remotely
* git is a popular version control system which can also pull code from online repositories - again, useful should a system admin ned to do work
* zenity and gksu allow displaying dialogs from script programs - useful for putting together quick tools for fixing the system
* geany - is a programming environment, very useful for teaching programming skills. When you need to modify configuraiton files, this will be more useful than a plain text editor.
* gitso - a screen sharing tool useful to requesting help from persons at a remote computer.

Beyond these, you have the option of using the Lubuntu Software Centre, or the Synaptic Package Manager at this point (both available under Start > System Tools), or you can use a terminal and use apt-get.

For the Partimus project, the following are relevant:

	libreoffice chromium-browser gimp krita openshot blender audacity scribus geany inkscape vlc flashplugin-installer

As root, you can add files to the /etc/skel folder; any file in the /etc/skel folder will be copied into any subsequently newly created user. Customize user default settings through this.

If you are using a virtual machine, shut it down instead at this point, and take a snaptshot; then start it again.

# 3/ Set up ISO build environment

(this steup will be eventually automated via bash script)

To prep the custom ISO build, install the following packages

	dialog squashfs-tools casper ubiquity-frontend-debconf user-setup discover xresprobe

Then use dpkg to install respin from deb. You can get a copy of respin from my github:

	git clone https://github.com/taikedz/remastersys
	dpkg -i remastersys/respin-master/respin_1.2.1/respin_1.2.1_all.deb

Note - I have reviewed the code of the respin script, and have done some cleanup on it. It is available through https://github.com/taikedz/our-pxe repo, in customizer/respin.sh

Copy that script to /usr/bin/respin.sh and replace any "respin" commands below with "respin.sh" instead

In a terminal, as root, run

	respin dist my-custom-distro.iso

This will build a new ISO for you.

Another option is to run

	respin cdfs

This will create the directory structure for a CD, without creating the CD itself - the documentation for respin advises that this is for tweaking the image further before CD creation, but is beyond the current scoipe of our activities.

If you need to clear out customizations from a previous attempt, use

	respin clean

This will remove the previous customization session.

# 4/ ISO is ready

You can now use the custom install CD to set up your other computers.

Burn it to a CD or copy it to a USB stick, or serve it over the network.

When installing, do the following:

1. Setup the standard user as an administrator. When first prompted to create a user at first reboot, this will already be the case, so call the user something like "(school name)-admin"

2. Once logged into the desktop, create a new user "student" with a password; do NOT grant admin privileges.

All the computers installed with this custom ISO will have the customizations you set previsouly during OEM mode. When booting from this CD, opt to immediately install. An issue with the LiveCD user creation prevents any live users from being created, so you can't do much with it. I'll look into this as a post-project task.


