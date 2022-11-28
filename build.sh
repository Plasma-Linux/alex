#!/bin/sh

########################################################
# alex is PlasmaLinux and Ubuntu or Debian iso builder #
# Mail->plasmalinuxjapan@gmail.com                     #
########################################################

#config設定
ubuntu_repo_url=""
ubuntu_code_name=""
arch=""
iso_name=""
iso_sub_name=""

#必要なディレクトリの作成
mkdir chroot
mkdir out
mkdir work
mkdir image

#必要な依存関係のインストール
sudo chmod 775 ./deps.sh
sudo ./deps.sh

#debootstrtap実行
sudo debootstrap --arch=$arch $ubuntu_code_name chroot $ubuntu_repo_url

#ファイルシステムのマウント
sudo mount --bind /dev chroot/dev
sudo mount --bind /run chroot/run

#chroot実行
sudo chmod 775 ./chroot.sh
sudo ln -f $SCRIPT_DIR/chroot.sh chroot/root/chroot.sh

#chroot.shの削除
sudo rm $SCRIPT_DIR/alex/chroot/root/chroot.sh

#マウント解除(一時的)
sudo umount chroot/dev
sudo umount chroot/run

#カーネルのコピー
mkdir -p image/{casper,isolinux,install}
sudo cp chroot/boot/vmlinuz-**-**-generic image/casper/vmlinuz
sudo cp chroot/boot/initrd.img-**-**-generic image/casper/initrd

#memtest86(BIOS/UEFI)をコピー
sudo cp chroot/boot/memtest86+.bin image/install/memtest86+

wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O image/install/memtest86-usb.zip
unzip -p image/install/memtest86-usb.zip memtest86-usb.img > image/install/memtest86
rm -f image/install/memtest86-usb.zip

#マニフェストの作成
sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/discover/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop

#chrootで作成した環境を圧縮
sudo mksquashfs chroot image/casper/filesystem.squashfs
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

#インストーラーにあるファイルの作成
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

#UEFIの設定
mkdir work/bi
cd work

dd if=/dev/zero of=bi.img bs=1M count=32
sudo mkfs.vfat bi.img
sudo mount bi.img bi/

sudo grub-install --target x86_64-efi --efi-directory bi/ --boot-directory=bi/boot/ --removable --uefi-secure-boot

wget http://ftp.jp.debian.org/debian/pool/main/g/grub-efi-ia32-signed/grub-efi-ia32-signed_1+2.06+3~deb11u1_i386.deb
wget http://ftp.jp.debian.org/debian/pool/main/s/shim-signed/shim-signed_1.38+15.4-7_i386.deb
wget http://ftp.jp.debian.org/debian/pool/main/g/grub2/grub-efi-ia32-bin_2.06-3~deb11u1_i386.deb

mkdir bi32


dpkg-deb -x shim-signed_1.38+15.4-7_i386.deb bi32/
sudo cp --preserve=mode,timestamp bi32/usr/lib/shim/shimia32.efi.signed bi/EFI/BOOT/BOOTIA32.efi

dpkg-deb -x grub-efi-ia32-signed_1+2.04+20_i386.deb bi32/
sudo cp --preserve=mode,timestamps bi32/usr/lib/grub/i386-efi-signed/grubia32.efi.signed bi/EFI/BOOT/GRUBIA32.EFI

dpkg-deb -x grub-efi-ia32-bin_2.06-3~deb11u1_i386.deb bi32/
sudo cp --preserve=mode,timestamp -r bi32/usr/lib/grub/i386-efi bi/boot/grub/
sudo rm -r bi/boot/grub/i386-efi/monolithic/

#FI起動イメージをimageにコピーしてアンマウント
sudo cp -ar bi/boot/ ../image/
sudo cp -ar bi/EFI/ ../image/
sudo umount bi
sudo chown 1000:1000 -R ../image/boot/ ../image/EFI/

#元のディレクトリに戻る
cd $HOME
cd $HOME/alex/image

#ディレクトリの作成
mkdir EFI/DEBIAN

#grub.cfgを見に行くように仕掛ける
cat <<EOF> image/EFI/BOOT/grub.cfg
#search.fs_uuid XXXX-XXXX root
search --set=root --file /.disk/info
set prefix=(\$root)'/boot/grub'
configfile \$prefix/grub.cfg
EOF

#32bitのサポート
(
   dd if=/dev/zero of=efi.img bs=1M count=10 && \
   sudo mkfs.vfat efi.img && \
   LC_CTYPE=C mmd -i efi.img efi efi/boot efi/debian boot boot/grub && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/DEBIAN/grub.cfg ::efi/debian/ && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/BOOT/BOOTIA32.efi ::efi/boot/ && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/BOOT/GRUBIA32.EFI ::efi/boot/ && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/BOOT/grub.cfg ::boot/grub/ && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/BOOT/BOOTX64.EFI ::efi/boot/ && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/BOOT/grubx64.efi ::efi/boot/ && \
   LC_CTYPE=C mcopy -i efi.img ./EFI/BOOT/mmx64.efi ::efi/boot/ && \
   mv efi.img ./boot/grub/
)

#Legacyで使うGrubイメージcore.imgを生成
grub-mkstandalone \
--format=i386-pc \
--output=isolinux/core.img \
--install-modules="linux16 linux normal iso9660 biosdisk memdisk search configfile tar ls" \
--modules="linux16 linux normal iso9660 biosdisk search configfile" \
--locales="" \
--fonts="" \
"/boot/grub/grub.cfg=EFI/BOOT/grub.cfg"

#boot.imgを作成
cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > boot/grub/boot.img

#core.imgを削除
rm isolinux/core.img

#Grubの設定ファイルを作成
cat << EOF > boot/grub/grub.cfg
search --set=root --file /.disk/info

if loadfont /boot/grub/fonts/unicode.pf2 ; then
    set gfxmode=auto
    insmod efi_gop
    insmod efi_uga
    insmod gfxterm
    terminal_output gfxterm
else
    insmod all_video
fi

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

#必要モジュールをisolinuxディレクトリにコピー
cp -a /usr/lib/ISOLINUX/isolinux.bin isolinux/
cp -a /usr/lib/syslinux/modules/bios/* isolinux/

#rast.run実行の準備
cd $HOME
cd $SCRIPT_DIR/alex/
sudo mount --bind /dev chroot/dev
sudo mount --bind /run chroot/run

#rast.runの実行
sudo chmod 775 ./rast.run
sudo ln -f $SCRIPT_DIR/rast.run chroot/root/rast.run

#rast.runの削除
sudo rm $SCRIPT_DIR/alex/chroot/root/rast.run

#isoファイルの作成
cd $HOME
cd $SCRIPT_DIR/alex/image
sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v -e 'md5sum.txt' -e 'boot.img' -e 'efi.img' -e 'isolinux.bin' > md5sum.txt)"

sudo xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "$iso_sub_name" \
   -out ../$iso_name.iso \
   -isohybrid-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
   --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
   --grub2-boot-info \
   -b boot/grub/boot.img \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
      --eltorito-catalog boot/grub/boot.cat \
   -append_partition 2 0xef boot/grub/efi.img \
   -eltorito-alt-boot \
      -e boot/grub/efi.img \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
   ./

exit0
