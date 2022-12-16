#!/bin/sh
sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt -y install \
    binutils \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools

    exit0
