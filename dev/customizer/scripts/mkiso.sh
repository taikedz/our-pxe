#!/bin/bash

# Public domain script from -- https://help.ubuntu.com/community/InstallCDCustomization

IMAGE=custom.iso
BUILD=/opt/cd-image/

mkisofs -r -V "Custom Ubuntu Install CD" \
            -cache-inodes \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o $IMAGE $BUILD
