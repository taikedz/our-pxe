# our-pxe

A simple Ubuntu ISO customization and PXE setup tool.

Users of the project should be enabled to:

* customize an ISO
* setup an image-serving server
* start a target PC and apply the image

# ISO Customization

ISO customization is provided by way of the `bin/remaster.sh` script. It is an interactive, guided script that requires some technical knowledge to use effectively.

You need to have an original ISO handy from the Ubuntu website (any desktop flavour should do), and run the script on it. run `remaster.sh --help` for info.

For customization, you will be dropped into a `chroot` environment in which you can customize any APT packages, the `/etc/skel` directory, add custom `.mozilla` directories in the skel directory... customize as you see fit.

An ISO will then be created for you to either burn to DVD, USB, or provide on the network.

# Image Server

The `bin/setup-pxe.sh` script takes as arguments the name of a distro to serve, as well as a path to an ISO, and sets up a fresh PXE server to serve it.

The script presume the Ubuntu instance is a fresh install without pre-existing PXE setup.

The `PXE_on_Ubuntu.md` file documents the entire process, specifically for Ubuntu 14.04.

