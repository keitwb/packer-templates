#!/bin/bash -xe

# Removing leftover leases and persistent rules
echo "cleaning up dhcp leases"
rm /var/lib/dhcp/*

# Make sure Udev doesn't block our network
echo "cleaning up udev rules"
rm -rf /dev/.udev/
rm /lib/udev/rules.d/75-persistent-net-generator.rules

echo "Adding a 2 sec delay to the interface up, to make the dhclient happy"
echo "pre-up sleep 2" >> /etc/network/interfaces

sed -i 's/timeout=5/timeout=1/' /boot/grub/grub.cfg

# Zero out the free space to save space in the final image:
echo "Zeroing device to make space..."
aptitude -y install zerofree psmisc
apt-get clean

ROOT_FS=$(mount | grep 'on / type' | awk '{ print $1 }')
## Kill running services
echo 'Killing some processes...'
pkill rpc
pkill dhclient
pkill rsyslog
pkill VBoxService
sleep 5s 
echo 'Remounting readonly...'
mount -oremount,ro $ROOT_FS
echo 'Running zerofree...'
zerofree $ROOT_FS

