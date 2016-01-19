#!/bin/sh
#
# Simple script to upgrade Libreswan on Ubuntu and Debian
#
# Copyright (C) 2015 Lin Song
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
# Unported License: http://creativecommons.org/licenses/by-sa/3.0/
#
# Attribution required: please include my name in any derivative and let me
# know how you have improved it!

# Check https://libreswan.org and update version number if necessary
SWAN_VER=3.16

if [ "$(lsb_release -si 2>/dev/null)" != "Ubuntu" ] && [ "$(lsb_release -si 2>/dev/null)" != "Debian" ]; then
  echo "Looks like you aren't running this script on a Ubuntu or Debian system."
  exit 1
fi

if [ "$(id -u)" != 0 ]; then
  echo "Sorry, you need to run this script as root."
  exit 1
fi

/usr/local/sbin/ipsec --version 2>/dev/null | grep -qs "Libreswan"
if [ "$?" != "0" ]; then
  echo "This upgrade script requires you already have Libreswan installed."
  echo "Aborting."
  exit 1
fi

/usr/local/sbin/ipsec --version 2>/dev/null | grep -qs "Libreswan ${SWAN_VER}"
if [ "$?" = "0" ]; then
  echo "It looks like you already have Libreswan ${SWAN_VER} installed! "
  echo
  printf "Do you wish to continue anyway? [y/N] "
  read -r response
  case $response in
    [yY][eE][sS]|[yY])
      echo
      ;;
    *)
      echo "Aborting."
      exit 1
      ;;
  esac
fi

clear

echo "Welcome! This upgrade script will build and install Libreswan ${SWAN_VER} on your server."
echo "This is intended for use on VPN servers with an older version of Libreswan installed."
echo "Your existing VPN configuration files will NOT be modified."

if [ "$(sed 's/\..*//' /etc/debian_version 2>/dev/null)" = "7" ]; then
  echo
  echo "IMPORTANT NOTE for Debian 7 (Wheezy) users:"
  echo "A workaround is required for your system. See: https://github.com/hwdsl2/setup-ipsec-vpn#installation"
  echo "Continue only if you have already completed the workaround."
fi

echo
printf "Do you wish to continue? [y/N] "
read -r response
case $response in
  [yY][eE][sS]|[yY])
    echo
    echo "Please be patient. Setup is continuing..."
    echo
    ;;
  *)
    echo "Aborting."
    exit 1
    ;;
esac

# Create and change to working dir
mkdir -p /opt/src
cd /opt/src || { echo "Failed to change working directory to /opt/src. Aborting."; exit 1; }

# Update package index and install wget and nano
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y install wget nano

# Install necessary packages
apt-get -y install libnss3-dev libnspr4-dev pkg-config libpam0g-dev \
        libcap-ng-dev libcap-ng-utils libselinux1-dev \
        libcurl4-nss-dev libgmp3-dev flex bison gcc make \
        libunbound-dev libnss3-tools libevent-dev
apt-get -y --no-install-recommends install xmlto
apt-get -y install xl2tpd

# Compile and install Libreswan (https://libreswan.org/)
SWAN_FILE="libreswan-${SWAN_VER}.tar.gz"
SWAN_URL="https://download.libreswan.org/${SWAN_FILE}"
wget -t 3 -T 30 -nv -O "$SWAN_FILE" "$SWAN_URL"
[ ! -f "$SWAN_FILE" ] && { echo "Could not retrieve Libreswan source file. Aborting."; exit 1; }
/bin/rm -rf "/opt/src/libreswan-${SWAN_VER}"
tar xvzf "$SWAN_FILE" && rm -f "$SWAN_FILE"
cd "libreswan-${SWAN_VER}" || { echo "Failed to enter Libreswan source directory. Aborting."; exit 1; }
make programs && make install

# Restart services
/usr/sbin/service ipsec restart
/usr/sbin/service xl2tpd restart

# Check if Libreswan install was successful
/usr/local/sbin/ipsec --version 2>/dev/null | grep -qs "${SWAN_VER}"
if [ "$?" != "0" ]; then
  echo
  echo "Sorry, something went wrong."
  echo "Libreswan ${SWAN_VER} was NOT installed successfully."
  echo "Exiting script."
  exit 1
fi

echo
echo "Congratulations! Libreswan ${SWAN_VER} was installed successfully!"

exit 0
