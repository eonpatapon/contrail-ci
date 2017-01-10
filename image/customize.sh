#!/bin/bash -x

set -e

basedir=$(dirname "$0")
rootdir=$1

# common needs rootdir to already be defined.
. /usr/share/vmdebootstrap/common/customise.lib

trap cleanup 0

mount_support

# Remove sources added by vmdebootstrap since cloud-init will add them
rm ${rootdir}/etc/apt/sources.list.d/base.list

# Prepare apt for installing packages in the chroot
echo "deb http://localhost:3142/ftp.fr.debian.org/debian/ jessie main" > ${rootdir}/etc/apt/sources.list
echo "deb http://localhost:3142/ftp.fr.debian.org/debian/ jessie-backports main" >> ${rootdir}/etc/apt/sources.list
chroot ${rootdir} apt update

# Apply debconf-selections before installing the packages
if [ -f ${basedir}/debconf-selections ]; then
  cp ${basedir}/debconf-selections ${rootdir}/debconf-selections
  chroot ${rootdir} debconf-set-selections /debconf-selections
  chroot ${rootdir} rm -f /debconf-selections
fi

# prevents apt to start daemons in the chroot
disable_daemons

chroot ${rootdir} apt-get -q -y install openssh-server tcpdump oping fping ethtool \
                                screen locales

# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=783847
chroot ${rootdir} apt-get -q -y -t jessie-backports install cloud-init

# remove previously added sources
rm ${rootdir}/etc/apt/sources.list

remove_daemon_block

chroot ${rootdir} dpkg -l

# copy cloud-init configuration
[[ -f ${basedir}/cloud.cfg ]] && cp ${basedir}/cloud.cfg ${rootdir}/etc/cloud/
cat << EOF > ${rootdir}/etc/cloud/cloud.cfg.d/00_datasource.cfg
datasource:
  Ec2:
    timeout: 1
    max_wait: 120
    metadata_urls: []
EOF
# - http://169.254.169.254:80

# no need to spawn extra getty
rm -f ${rootdir}/lib/systemd/system/getty.target.wants/getty-static.service
# no not resolve IPs when connecting via SSH
echo "UseDNS no" >> ${rootdir}/etc/ssh/sshd_config
# include virtio modules in initrd
echo "virtio_pci\nvirtio_blk" >> ${rootdir}/etc/initramfs-tools/modules
# we don't need floppy I guess
echo "blacklist floppy" > ${rootdir}/etc/modprobe.d/floppy-blacklist.conf
# for locale generation
echo "en_US.UTF-8 UTF-8" >> ${rootdir}/etc/locale.gen

echo "Customisation complete"
