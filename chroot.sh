#!/bin/sh

#config設定
ubuntu_repo_url=""
ubuntu_code_name=""
os_name=""
os_code_name=""
os_ver=""
full_name=""
support_url=""
home_url=""
id=""


#追加でファイルシステムのマウントと環境変数の設定
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C

#ホスト名の設定
echo "ubuntu-fs-live" > /etc/hostname

#リポジトリミラーの設定ファイルの作成と設定
cat <<EOF> /etc/apt/sources.list
deb $ubuntu_repo_url $ubuntu_code_name main
deb $ubuntu_repo_url $ubuntu_code_name universe
deb $ubuntu_repo_url $ubuntu_code_name multiverse

deb $ubuntu_repo_url $ubuntu_code_name-updates main
deb $ubuntu_repo_url $ubuntu_code_name-updates universe
deb $ubuntu_repo_url $ubuntu_code_name-updates multiverse

deb $ubuntu_repo_url $ubuntu_code_name-backports main
deb $ubuntu_repo_url $ubuntu_code_name-backports universe
deb $ubuntu_repo_url $ubuntu_code_name-backports multiverse

deb $ubuntu_repo_url $ubuntu_code_name-security main
deb $ubuntu_repo_url $ubuntu_code_name-security universe
deb $ubuntu_repo_url $ubuntu_code_name-security multiverse
EOF

#updateとfull-upgradeの実行
apt update && apt full-upgrade -y && apt autoremove -y

#machine-idを構成
dbus-uuidgen > /etc/machine-id
mkdir /var/lib/dbus
ln -fs /etc/machine-id /var/lib/dbus/machine-id

#/sbin/initctlをインストールしないように細工
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

#もう一度更新をかける
apt update && apt full-upgrade -y && apt autoremove -y

#必要なパッケージのインストール
apt install -y \
sudo \
ubuntu-standard \
casper \
lupin-casper \
discover \
laptop-detect \
os-prober \
network-manager \
resolvconf \
net-tools \
wireless-tools \
wpagui \
locales \
grub-common \
grub-gfxpayload-lists \
grub-pc \
grub-pc-bin \
grub2-common \
ubiquity \
ubiquity-casper \
ubiquity-frontend-gtk \
ubiquity-slideshow-ubuntu \
ubiquity-ubuntu-artwork \
plymouth-theme-ubuntu-logo \
ubuntu-gnome-desktop \
ubuntu-gnome-wallpapers \
clamav-daemon \
terminator \
apt-transport-https \
curl \
vim \
nano \
less \
inetutils-ping

apt install -y --no-install-recommends linux-generic
apt install -y --no-install-recommends `check-language-support -l ja`

#ロケールとリゾルバの設定
dpkg-reconfigure locales
dpkg-reconfigure resolvconf

#NetworkManagerの設定
cat <<EOF> /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq

[ifupdown]
managed=false

[device]
wifi.scan-rand-mac-address=no
EOF

#os-releaseとlsb-releaseの設定
cat <<EOF> /etc/os-release
PRETTY_NAME="$full_name"
NAME="$os_name"
VERSION_ID="$os_ver"
VERSION="$os_ver ($os_code_name)"
VERSION_CODENAME=$ubuntu_code_name
ID=$id
ID_LIKE="ubuntu"
HOME_URL="$home_url"
SUPPORT_URL="home_url"
BUG_REPORT_URL="https://bugs.kde.org/"
PRIVACY_POLICY_URL="home_url"
UBUNTU_CODENAME=$ubuntu_code_name
EOF

cat <<EOF> /etc/lsb-release
DISTRIB_ID=$id
DISTRIB_RELEASE=$os_ver
DISTRIB_CODENAME=$os_code_name
DISTRIB_DESCRIPTION="$full_name"
EOF

#設定変更の反映
dpkg-reconfigure network-manager

#machine-idを削除
truncate -s 0 /etc/machine-id

#dpkgインストール先の待避を解除
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

#chrootから脱出
apt clean
rm -rf /tmp/*
umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0
exit
