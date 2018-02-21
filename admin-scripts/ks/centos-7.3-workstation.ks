install
lang en_US.UTF-8
keyboard us
timezone --utc America/New_York

network --noipv6 --onboot=yes --bootproto=dhcp

url --url http://192.168.21.205/CentOS-7-x86_64-Everything-1611/
repo --name=sigma-centos-7       --baseurl=http://sigma-yum.s3.amazonaws.com/sigma-centos-7
repo --name=sigma-epel           --baseurl=http://sigma-yum.s3.amazonaws.com/sigma-epel
repo --name=sigma-puppetlabs-el7 --baseurl=http://sigma-yum.s3.amazonaws.com/sigma-puppetlabs-el7

authconfig --enableshadow --enablemd5
rootpw --iscrypted $6$YwlGsaqF$vEQPbllvtAFFs2Acqf4In.AUHJ38t3xuZhXMtAiU89juF.XYLd39kVs1biphUq0HnO0MnHxG96J4zm78A.1NO/
user --name=sigma --shell=/bin/bash --iscrypted --password=$6$T5nmegGU$EEPcWaxlJnEjesazGnPhNG3J4w9eVc1okv8AuPANKgjm4o2Rv1B3/Fw9kAvbk2DM/4Z2L8VlbwSBhLbxjv20y0

selinux --permissive
firewall --service=ssh

bootloader --location=mbr --driveorder=sda --append="crashkernel=auth"

# Disk Partitioning
clearpart --all --initlabel --drives=sda
part /boot --fstype=ext4 --ondisk=sda  --size=1000
part pv.1                --ondisk=sda  --size=1     --grow
volgroup vg_os --pesize=4096 pv.1

logvol /              --fstype=ext4  --vgname=vg_os --size=50000 --name=lv_root
logvol /tmp           --fstype=ext4  --vgname=vg_os --size=25000 --name=lv_tmp
logvol /var           --fstype=ext4  --vgname=vg_os --size=25000 --name=lv_var
logvol /var/log       --fstype=ext4  --vgname=vg_os --size=25000 --name=lv_var_log
logvol /var/log/audit --fstype=ext4  --vgname=vg_os --size=25000 --name=lv_var_log_audit
logvol swap                          --vgname=vg_os --size=25000 --name=lv_swap


reboot

# Packages
%packages
@base
@core
@X Window System
@gnome-desktop
@Development Tools
-*firmware
-iscsi*
-fcoe*
-b43-openfwwf
-efibootmgr
kernel-firmware
wget
rsync
sudo
net-tools
ipa-client
puppet
firefox
%end

%pre
exec < /dev/tty3 > /dev/tty3
chvt 3
(
timestamp=$( date )
echo "Finished Pre Install: ${timestamp}"
) 2>&1 | /usr/bin/tee /root/install-pre.out 2>&1
chvt 1
%end

%post
exec < /dev/tty3 > /dev/tty3
chvt 3
(
timestamp=$( date )
echo "Finished Post Install: ${timestamp}"
) 2>&1 | /usr/bin/tee /root/install-post.out 2>&1
chvt 1
%end

