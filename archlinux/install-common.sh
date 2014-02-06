#!/usr/bin/env bash

# Heavily borrowed from https://github.com/elasticdog/packer-arch

DISK='/dev/vda'
FQDN='vagrant-arch'
KEYMAP='us'
LANGUAGE='en_US.UTF-8'
PASSWORD=$(/usr/bin/openssl passwd -crypt 'vagrant')
TIMEZONE='EST'

CONFIG_SCRIPT='/usr/local/bin/arch-config.sh'
ROOT_PARTITION="${DISK}1"
TARGET_DIR='/mnt'

echo "==> creating /root partition on ${DISK}"
/usr/bin/sfdisk ${DISK} <<EOF
1,,83,*
EOF

echo '==> creating /root filesystem (ext4)'
/usr/bin/mkfs.ext4 -F -m 0 -q -L root ${ROOT_PARTITION}

echo "==> mounting ${ROOT_PARTITION} to ${TARGET_DIR}"
/usr/bin/mount -o noatime,errors=remount-ro ${ROOT_PARTITION} ${TARGET_DIR}

echo '==> bootstrapping the base installation'
/usr/bin/pacstrap ${TARGET_DIR} base base-devel
/usr/bin/arch-chroot ${TARGET_DIR} pacman -S --noconfirm openssh grub
/usr/bin/arch-chroot ${TARGET_DIR} grub-install --target=i386-pc --recheck ${DISK}
/usr/bin/arch-chroot ${TARGET_DIR} grub-mkconfig -o /boot/grub/grub.cfg
/usr/bin/sed -i 's/set timeout=5/set timeout=1/' "${TARGET_DIR}/boot/grub/grub.cfg"

echo '==> generating the filesystem table'
/usr/bin/genfstab -p ${TARGET_DIR} >> "${TARGET_DIR}/etc/fstab"

echo '==> generating the system configuration script'
/usr/bin/install --mode=0755 /dev/null "${TARGET_DIR}${CONFIG_SCRIPT}"

cat <<-EOF > "${TARGET_DIR}${CONFIG_SCRIPT}"
	echo '${FQDN}' > /etc/hostname
	/usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
	echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf
	/usr/bin/sed -i 's/#${LANGUAGE}/${LANGUAGE}/' /etc/locale.gen
	/usr/bin/locale-gen
	/usr/bin/mkinitcpio -p linux
	/usr/bin/usermod --password ${PASSWORD} root
	# https://wiki.archlinux.org/index.php/Network_Configuration#Device_names
	/usr/bin/ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules
	/usr/bin/ln -s '/usr/lib/systemd/system/dhcpcd@.service' '/etc/systemd/system/multi-user.target.wants/dhcpcd@eth0.service'
	/usr/bin/sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
	/usr/bin/systemctl enable sshd.service

	# Vagrant-specific configuration
	/usr/bin/groupadd vagrant
	/usr/bin/useradd --password ${PASSWORD} --comment 'Vagrant User' --create-home --gid users --groups vagrant vagrant
	echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > /etc/sudoers.d/10_vagrant
	echo 'vagrant ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/10_vagrant
	/usr/bin/chmod 0440 /etc/sudoers.d/10_vagrant
	/usr/bin/install --directory --owner=vagrant --group=users --mode=0700 /home/vagrant/.ssh
	/usr/bin/curl --output /home/vagrant/.ssh/authorized_keys https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
	/usr/bin/chown vagrant:users /home/vagrant/.ssh/authorized_keys
	/usr/bin/chmod 0600 /home/vagrant/.ssh/authorized_keys

  # Install yaourt
  TMP_DIR=$(mktemp -d)
  cd $TMP_DIR
  /usr/bin/curl https://aur.archlinux.org/packages/pa/package-query/package-query.tar.gz | tar -zx
  pushd package-query && /usr/bin/makepkg --asroot --noconfirm -s PKGBUILD && /usr/bin/pacman -U --noconfirm package-query*.pkg.tar.xz && popd
  /usr/bin/curl https://aur.archlinux.org/packages/ya/yaourt/yaourt.tar.gz | tar -zx
  pushd yaourt && /usr/bin/makepkg --asroot --noconfirm -s PKGBUILD && /usr/bin/pacman -U --noconfirm yaourt*.pkg.tar.xz && popd
  /usr/bin/rm -rf $TMP_DIR

  # Install Chef manually since Opscode's Omnibus installer doesn't work with ArchLinux
  /usr/bin/pacman -S --noconfirm ruby
  echo '==> Installing Chef from Ruby Gem.  This could take a while...'
  /usr/bin/gem install --no-document --no-user-install chef

	# clean up
	/usr/bin/yes | /usr/bin/pacman -Scc
  gem sources -c
EOF

echo '==> entering chroot and configuring system'
/usr/bin/arch-chroot ${TARGET_DIR} ${CONFIG_SCRIPT}
rm "${TARGET_DIR}${CONFIG_SCRIPT}"

/usr/bin/install --mode=0644 poweroff.timer "${TARGET_DIR}/etc/systemd/system/poweroff.timer"

echo '==> installation complete!'
/usr/bin/sleep 3
/usr/bin/umount ${TARGET_DIR}
reboot
