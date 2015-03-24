#!/bin/bash

# Public domain script from -- https://help.ubuntu.com/community/InstallCDCustomization


BUILD=/opt/cdrom-image
APTCONF=/opt/apt-ftparchive/release.conf
DISTNAME=trusty

pushd $BUILD
apt-ftparchive -c $APTCONF generate /opt/apt-ftparchive/apt-ftparchive-deb.conf
apt-ftparchive -c $APTCONF generate /opt/apt-ftparchive/apt-ftparchive-udeb.conf
apt-ftparchive -c $APTCONF generate /opt/apt-ftparchive/apt-ftparchive-extras.conf
apt-ftparchive -c $APTCONF release $BUILD/dists/$DISTNAME > $BUILD/dists/$DISTNAME/Release

gpg --default-key "9A1E3CD8" --output $BUILD/dists/$DISTNAME/Release.gpg -ba $BUILD/dists/$DISTNAME/Release
find . -type f -print0 | xargs -0 md5sum > md5sum.txt
popd

