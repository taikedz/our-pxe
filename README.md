# our-pxe

A simple Ubuntu ISO customization and PXE setup

The goal of the project is to provide a way to make a custom ISO and deploy it to multiple machines on a network, with minimal technical knowledge requirements on the end-user/deployer.

Users of the project should be enabled to:

* customize an ISO
* setup an image-serving server
* start a target PC and apply the image
* create an image of the server for flashing the server

Documentation and guides for each facet will be provided.

# ISO Customization

The ./customizer directory hosts scripts, resources and instructions for building a custom ISO from a Ubuntu server base

Current version supported is 14.04

The goal of the project is to

* provide step-by-step instructions to go from a base ISO to a custom ISO, using a fresh Ubuntu server as working environment.
* provide an automation script that can run in a fresh Ubuntu server to automate as much of the build as possible.

# Image Server

The ./pxe-server directory is to contain a recipe manual for setting up a Ubuntu-based PXE server.

The working environment will assume a fresh Ubuntu server install.

# Progress

## Customization

Current efforts on customizatio nhave led me to favour using respin - see the ./respin directory for details

This allows anyone to install a Ubuntu-based distro, customize it, then use the respin script to produce an installable ISO with all customizations.

Some issues remain to be resolved with respin:

* there is no live user on the respun DVD (minor issue for this project)
* 14.04 - the respinning procedure [disables DNS](https://help.ubuntu.com/community/LiveCDCustomization#line-86) (due to change in 14.04's structure) After install, need to symlink /etc/resolv.conf -> /run/resolvconf/resolv.conf and restart networking / reboot.

## Server

After quite a bit of work with trying to set up PXE from a fresh Ubuntu server install, it seems this type of task is no small feat. I've been working solely on virtualbox instances so far, but may need to bring the tasks to actual hardware and isolate the network.

An alternate solution based on clonezilla is to be investigated, where the main problem to workaround will be to bypass the limitation whereby clonezilla expects the target disk to be the same size as the disk the image was produced from.

Yet another alternative would be to create a boot CD that would allow pulling the image from the server which would be an rsync server, after doing simple partitioning. No ISO creation - just a base read-only image.
