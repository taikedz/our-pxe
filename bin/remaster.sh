#!/bin/bash

# leave these here for backwards compat ^_^
ORIGINAL_ISO_NAME=$1
NEW_ISO_NAME=$2
yespat='^(yes|y|YES|Y|aye?|AYE?)$'
ISOTASK=mountiso

function printhelp {
cat <<EOHELP

remaster.sh

Originally by Pat Natali https://github.com/beta0x64/remaster.sh
With contributions by Tai Kedzierski https://github.com/taikedz/remaster.sh

Usage:

    $0 path/to/old.iso path/to/new.iso [--entry=ENTRYPOINT]
    $0 --iniso=old.iso --outiso=new.iso [--entry=ENTRYPOINT]

ENTRYPOINT is a flag at which you can resume a function of the script. The supported entry points are:

mountiso
    Starts the process by mounting the original ISO,
    and proceeds through the rest of the script

customizeiso
    Re-starts the ISO cusotmization step,
    and proceeds through the rest of the script

customizekernel
    Re-starts the post-ISO customization step,
    and proceeds through the rest of the script

buildiso
    Re-builds the ISO from the currrent state.
    Requires that the previous steps to have been run before
    and for ./livecdtemp to not have been removed or broken

EOHELP
}

if [[ -z $@ ]]; then
    printhelp
    exit
fi

for term in $@; do
    case $term in
        --iniso=*)
            ORIGINAL_ISO_NAME=${term#--iniso=}
            ;;
        --outiso=*)
            NEW_ISO_NAME=${term#--outiso=}
            ;;
        --entry=*)
            ISOTASK=${term#--entry=}
            ;;
        --help)
            printhelp
            exit
            ;;
        *)
            [[ ! -f "$term" ]] && echo "Unknown option $term"
            exit 98
            ;;
    esac
done

if [[ -z $ORIGINAL_ISO_NAME || -z $NEW_ISO_NAME ]]; then
    printhelp
    exit
fi

read -p "Install pre-reqs? > " resp && [[ $resp =~ $yespat ]] && {
    echo "Installing or updating squashfs-tools and syslinux"
    sudo apt-get update && sudo apt-get install squashfs-tools syslinux
}


[[ $ISOTASK = 'mountiso' ]] && {
# Step 1:
# Make a parent directory for our Live USB
mkdir -p ./livecdtmp
cd ./livecdtmp

if [[ -f "../$ORIGINAL_ISO_NAME" ]]; then
    ORIGINAL_ISO_NAME="../$ORIGINAL_ISO_NAME"
elif [[ ! -f "$ORIGINAL_ISO_NAME" ]]; then
    echo "$PWD/$ORIGINAL_FILE_NAME cannot be found. Please specify its full path with the --iniso parameter." >&2
    exit 2
fi


# Step 2:
mkdir -p mnt
echo "Logging into root"
sudo su -c "echo 'SUDO Logged in'"
# Mount the ISO as a loop filesystem to ./livecdtmp/mnt
# This will allow us to look at its insides, basically
sudo mount -o loop $ORIGINAL_ISO_NAME mnt
sudo mkdir extract-cd
# Copy all the ISO's innards except for filesystem.squashfs to extract-cd/
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract-cd
# Expand the squashed filesystem and put it into ./livecdtmp/edit so we can update the squashed filesystem with our new values it needs to boot and install properly
sudo unsquashfs mnt/casper/filesystem.squashfs
sudo mv squashfs-root edit

ISOTASK=customizeiso
} # ====================================

[[ $ISOTASK = 'customizeiso' ]] && {
# Step 3:
# This makes our terminal's "perspective" come from ./livecdtmp/edit/
sudo mount -o bind /run edit/run
sudo chroot edit mount -t proc none /proc
sudo chroot edit mount -t sysfs none /sys
sudo mount -o bind /dev/pts edit/dev/pts

#sudo chroot edit export HOME=/root
#sudo chroot edit export LC_ALL=C

# Step 4:
# Normally this is where you'd do your customizations.
# I recommend copying from your main system's /etc/apt/sources.list to your ISO's sources.list.
echo "Now make customizations from the CLI"
echo "If you want to replace the desktop wallpaper, use the instructions related to your window manager. You may have to replace the image somewhere under /usr/share"
echo "If you need to copy in new files to the ISO, use another terminal to copy to remaster/livecdtmp/extract-cd/ as root"
echo "To use apt-get properly, you may have to copy from your /etc/apt/sources.list to this ISO, then run apt-get update and finally resolvconf -u to connect to the internet"
echo "When you are done, just type 'exit' to continue the process"
sudo chroot edit

# Step 5:
# Back out of the chroot
#sudo chroot edit umount /proc || sudo chroot edit umount -lf /proc
echo "Backing out of the chroot"
sudo chroot edit umount /proc
sudo chroot edit umount /sys
#sudo chroot edit umount /dev/pts
sudo umount mnt
sudo umount edit/run
sudo umount edit/dev/pts

# =======
read -p "Are you happy with these changes? > " resp
[[ $resp =~ $yespat ]] && { ISOTASK=customizekernel; }
echo "You can re-run this step by executing '$0 --task=customizeiso'" >&2
} # ====================================

[[ $ISOTASK = 'customizekernel' ]] && {
echo "If you want to, you can enter kernel commands or other changes from outside of the ISO"
echo "If you want to turn off the 'try or install' screen, use these instructions: http://askubuntu.com/a/47613"
echo "isolinux.cfg and txt.cfg are in extract-cd/isolinux"
echo "If not, type exit again to begin the ISO creation process"
bash

# =======
read -p "Are you happy with these changes? > " resp
[[ $resp =~ $yespat ]] && { ISOTASK=buildiso; }
echo "You can re-run this step by executing '$0 --task=customizekernel'" >&2
} # ====================================

[[ $ISOTASK = 'buildiso' ]] && {
# Step 6:
sudo chmod +w extract-cd/casper/filesystem.manifest
echo "chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract-cd/casper/filesystem.manifest" | sudo sh >> ./remaster.log
sudo cp extract-cd/casper/filesystem.manifest extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' extract-cd/casper/filesystem.manifest-desktop
sudo rm extract-cd/casper/filesystem.squashfs
sudo mksquashfs edit extract-cd/casper/filesystem.squashfs
ISO_SIZE=`sudo du -sx --block-size=1 edit | cut -f1`
echo "printf $ISO_SIZE > extract-cd/casper/filesystem.size" | sudo sh >> ./remaster.log
sudo nano extract-cd/README.diskdefines
sudo rm extract-cd/md5sum.txt
echo "find extract-cd/ -type f -print0 | xargs -0 md5sum | grep -v extract-cd/isolinux/boot.cat | tee extract-cd/md5sum.txt" | sudo sh >> ./remaster.log
IMAGE_NAME='Custom ISO'
sudo mkisofs -D -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../$NEW_ISO_NAME extract-cd/
sudo chmod 775 ../$NEW_ISO_NAME

cd ..
isohybrid $NEW_ISO_NAME

echo "You can use root permissions to delete ./livecdtmp now."
}
