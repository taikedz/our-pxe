# our-pxe

A simple Ubuntu ISO customization and PXE setup

The goal of the project is to provide a way to make a custom ISO and deploy it to multiple machines on a network, with minimal technical knowledge requirements on the end-user/deployer.

Users of the project should be enabled to:

* customize an ISO
* setup a PXE server
* server the ISO from the PXE server
* create an image of the PXE server for flashing the server

Documentation and guides for each facet will be provided.

# ISO Customization

The ./customizer directory hosts scripts, resources and instructions for building a custom ISO from a Ubuntu server base

Current version supported is 14.04

The goal of the project is to

* provide step-by-step instructions to go from a base ISO to a custom ISO, using a fresh Ubuntu server as working environment.
* provide an automation script that can run in a fresh Ubuntu server to automate as much of the build as possible.

# PXE Server

The ./pxe-server directory is to contain a recipe manual for setting up a Ubuntu-based PXE server.

The working environment will assume a fresh Ubuntu server install.
