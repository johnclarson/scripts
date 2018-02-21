#!/usr/bin/env bash

mkdir /data

parted /dev/sdb mklabel GPT
parted --align=opt /dev/sdb mkpart primary ext4 0% 100%
pvcreate /dev/sdb1
vgcreate vg_data /dev/sdb1
lvcreate -l 100%FREE -n lv_data vg_data
mkfs.ext4 /dev/mapper/vg_data-lv_data
mount /dev/mapper/vg_data-lv_data /data
echo '/dev/mapper/vg_data-lv_data /data   ext4  defaults  0 0' >> /etc/fstab

mkdir /data/kvm/images
mkdir /data/kvm/extra_drives
rmdir /var/lib/libvirt/images
ln -s /data/kvm/images /var/lib/libvirt/images

virsh pool-define-as extra_drives dir - - - - "/data/kvm/extra_drives/"
virsh pool-define-as images dir - - - - "/data/kvm/images/"
virsh pool-build extra_drives
virsh pool-start extra_drives
virsh pool-autostart extra_drives
virsh pool-build images
virsh pool-start images
virsh pool-autostart images

systemctl restart libvirtd

