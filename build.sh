#!/bin/sh

#################################################
#                                               #
# Welcome to alex!                              #
# alex is isobuilder in Ubuntu or Debian        #
# alex devlopers is Jotch-96 and Fabric_Teacher #
#                                               #
# Jotch-96                                      #
# Mail:plasmalinuxjapan@gmail.com               #
# Twitter:@PlasmaLinux                          #
# Github:https://github.com/Plasma-Linux/       #
#                                               #
# Fabric_Teacher                                #
# Mail:fabricteacher@gmail.com                  #
# Github:https://github.com/GoldWolv/           #
#                                               #
#################################################

#ディレクトリの作成
mkdir chroot
mkdir out
mkdir work
mkdir image
mkdir image/bi

#config.shの実行
sudo chmod 775 ./config.sh
sudo ./config.sh

#debootstrapの実行
sudo debootstrap \
   --arch=$arch \
   --variant=$debootstrap_lebel \
   $ubuntu_code_name \
   chroot \
   $ubuntu_repo_url

#airootfsとスクリプトをchroot内にコピー
sudo cp -a airoootfs/ chroot/
sudo cp /chroot.sh
sudo cp /final-process.sh

#ファイルシステムのマウント
sudo mount --bind /dev chroot/dev
sudo mount --bind /run chroot/run

#chrootの実行
cd chroot/root
sudo chmod 775 ./chroot.sh
sudo ./chroot.sh

#ファイルシステムのアンマウント
sudo umount chroot/dev
sudo umount chroot/run

#カーネルイメージのコピー
sudo cp chroot/boot/vmlinuz-**-**-generic image/casper/vmlinuz
sudo cp chroot/boot/initrd.img-**-**-generic image/casper/initrd

#memtest86+のコピー
sudo cp chroot/boot/memtest86+.bin image/install/memtest86+

#memtest86(UEFI)の設定
wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O image/install/memtest86-usb.zip
unzip -p image/install/memtest86-usb.zip memtest86-usb.img > image/install/memtest86
rm -f image/install/memtest86-usb.zip

#Grub設定
touch image/ubuntu

#image/isolinux/grub.cfgの作成
cat <<EOF > image/isolinux/grub.cfg

search --set=root --file /ubuntu

insmod all_video

set default="0"
set timeout=30

menuentry "Try Ubuntu FS without installing" {
   linux /casper/vmlinuz boot=casper nopersistent toram quiet splash ---
   initrd /casper/initrd
}

menuentry "Install Ubuntu FS" {
   linux /casper/vmlinuz boot=casper only-ubiquity quiet splash ---
   initrd /casper/initrd
}

menuentry "Check disc for defects" {
   linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
   initrd /casper/initrd
}

menuentry "Test memory Memtest86+ (BIOS)" {
   linux16 /install/memtest86+
}

menuentry "Test memory Memtest86 (UEFI, long load time)" {
   insmod part_gpt
   insmod search_fs_uuid
   insmod chain
   loopback loop /install/memtest86
   chainloader (loop,gpt1)/efi/boot/BOOTX64.efi
}
EOF

#マニフェストの設定
sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/discover/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop

#squashfsの作成
sudo mksquashfs chroot image/casper/filesystem.squashfs

#filesystem.sizeを書く
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

#インストーラーファイルの作成
cat <<EOF > image/README.diskdefines
#define DISKNAME  Ubuntu from scratch
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

#UEFI imageの作成
grub-mkstandalone \
   --format=x86_64-efi \
   --output=isolinux/bootx64.efi \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"

#FAT16 UEFI boot disk imageの作成
(
   cd isolinux && \
   dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
   sudo mkfs.vfat efiboot.img && \
   LC_CTYPE=C mmd -i efiboot.img efi efi/boot && \
   LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)

#BIOS用イメージの作成
grub-mkstandalone \
   --format=i386-pc \
   --output=isolinux/core.img \
   --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls" \
   --modules="linux16 linux normal iso9660 biosdisk search" \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"

#Grub cdboot.imgの設定
cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img

#md5sum.txtの設定
sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v -e 'md5sum.txt' -e 'bios.img' -e 'efiboot.img' > md5sum.txt)"

#ISOLINUX (syslinux) boot menuの作成
cat <<EOF> isolinux/isolinux.cfg
UI vesamenu.c32

MENU TITLE Boot Menu
DEFAULT linux
TIMEOUT 600
MENU RESOLUTION 640 480
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL linux
 MENU LABEL Try Ubuntu FS
 MENU DEFAULT
 KERNEL /casper/vmlinuz
 APPEND initrd=/casper/initrd boot=casper

LABEL linux
 MENU LABEL Try Ubuntu FS (nomodeset)
 MENU DEFAULT
 KERNEL /casper/vmlinuz
 APPEND initrd=/casper/initrd boot=casper nomodeset
EOF

#syslinux bios modulesの設定
apt install -y syslinux-common && \
cp /usr/lib/ISOLINUX/isolinux.bin isolinux/ && \
cp /usr/lib/syslinux/modules/bios/* isolinux/

#isoファイルの作成
sudo xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "$iso_name" \
   -output "../$iso_name.iso" \
 -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
 -eltorito-boot \
     isolinux/isolinux.bin \
     -no-emul-boot \
     -boot-load-size 4 \
     -boot-info-table \
     --eltorito-catalog isolinux/isolinux.cat \
 -eltorito-alt-boot \
     -e /EFI/boot/efiboot.img \
     -no-emul-boot \
     -isohybrid-gpt-basdat \
 -append_partition 2 0xef EFI/boot/efiboot.img \
   "out"


   exit0
