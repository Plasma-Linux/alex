#!/bin/sh

#################################################
#                                               #
# Welcome to chroot!                            #
# The chroot allows the system to be completed. #
#                                               #
#################################################

#追加でファイルシステムのマウント
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C

#hostnameの設定
echo "ubuntu-fs-live" > /etc/hostname

#updateの実行
apt update

#systemdのインストール
apt install -y libterm-readline-gnu-perl systemd-sysv

#machine-idの設定
dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

#aptコマンドの実行
apt upgrade -y
apt autoremove -y

#パッケージのインストール
apt install -y \
binutils \
bzip2 \
cpio \
gzip \
p7zip \
p7zip-full \
tar \
unzip \
xz-utils \
zip \
ubuntu-minimal \
ubuntu-standard \
bash-completion \
dialog \
build-essential \
default-jre \
nano \
vim \
grub-pc \
grub-efi-amd64-bin \
grub-efi-ia32-bin \
os-prober \
isolinux \
syslinux-common \
memtest86+ \
casper \
lupin-casper \
ubiquity \
ubiquity-casper \
ubiquity-frontend-debconf \
ubiquity-frontend-gtk \
ubiquity-ubuntu-artwork \
efibootmgr \
sudo \
man-db \
manpages \
manpages-dev \
usb-modeswitch \
usbutils \
cups \
btrfs-progs \
dosfstools \
mtools \
ntfs-3g \
xfsprogs \
isc-dhcp-client \
dnsutils \
network-manager \
ppp \
pptp-linux \
resolvconf \
openssh-client \
wget \
crda \
wireless-regdb \
wireless-tools \
wpasupplicant \
netcat-openbsd \
rsync \
tcpdump

apt install -y --no-install-recommends linux-generic-hwe-22.04
apt install -y --no-install-recommends `check-language-support -l ja`

#final-processの実行
chmod 775 ./final-process.sh
 ./final-process.sh

#resolvconfの設定
dpkg-reconfigure resolvconf

#network-managerの設定
dpkg-reconfigure network-manager

#chrootから脱出する
truncate -s 0 /etc/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
apt-get clean
rm -rf /tmp/* ~/.bash_history
umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0
exit
