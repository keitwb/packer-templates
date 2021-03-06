#!/bin/bash

# Removing leftover leases and persistent rules
echo "cleaning up dhcp leases"
rm /var/lib/dhcp/*

# Make sure Udev doesn't block our network
echo "cleaning up udev rules"
rm /etc/udev/rules.d/70-persistent-net.rules
mkdir /etc/udev/rules.d/70-persistent-net.rules
rm -rf /dev/.udev/
rm /lib/udev/rules.d/75-persistent-net-generator.rules

echo "Adding a 2 sec delay to the interface up, to make the dhclient happy"
echo "pre-up sleep 2" >> /etc/network/interfaces

# Zero out the free space to save space in the final image:
#echo "Zeroing device to make space..."
#aptitude -y install zerofree
#ROOT_FS=$(mount | grep 'on / type' | awk '{ print $1 }')

## Kill running services
#fuser -m $ROOT_FS -k -w

#mount -oremount,ro $ROOT_FS
#zerofree $ROOT_FS
#mount -oremount,rw $ROOT_FS
#service ssh start

apt-get clean
