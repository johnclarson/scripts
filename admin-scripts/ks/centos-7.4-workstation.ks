install
lang en_US.UTF-8
keyboard us
timezone --utc America/New_York

network --noipv6 --onboot=yes --bootproto=dhcp

url --url="http://tftp.p1.sigma.dsci/CentOS-7-x86_64-Everything-1708"
repo --name="sigma-centos-7-base" --baseurl=http://yum.p1.sigma.dsci/sigma-centos-7-base
repo --name="sigma-centos-7-updates" --baseurl=http://yum.p1.sigma.dsci/sigma-centos-7-updates
repo --name="sigma-dockerrepo" --baseurl=http://yum.p1.sigma.dsci/sigma-dockerrepo
repo --name="sigma-epel" --baseurl=http://yum.p1.sigma.dsci/sigma-epel
repo --name="sigma-puppetlabs-el7" --baseurl=http://yum.p1.sigma.dsci/sigma-puppetlabs-el7
repo --name="sigma-foreman-1.15" --baseurl=http://yum.p1.sigma.dsci/sigma-foreman-1.15
repo --name="sigma-foreman-plugins-1.15" --baseurl=http://yum.p1.sigma.dsci/sigma-foreman-plugins-1.15
repo --name="sigma-sclo-rh-el7" --baseurl=http://yum.p1.sigma.dsci/sigma-sclo-rh-el7
repo --name="sigma-sclo-sclo-el7" --baseurl=http://yum.p1.sigma.dsci/sigma-sclo-sclo-el7

authconfig --enableshadow --enablemd5
rootpw --iscrypted $6$YwlGsaqF$vEQPbllvtAFFs2Acqf4In.AUHJ38t3xuZhXMtAiU89juF.XYLd39kVs1biphUq0HnO0MnHxG96J4zm78A.1NO/
user --name=sigma --shell=/bin/bash --iscrypted --password=$6$T5nmegGU$EEPcWaxlJnEjesazGnPhNG3J4w9eVc1okv8AuPANKgjm4o2Rv1B3/Fw9kAvbk2DM/4Z2L8VlbwSBhLbxjv20y0

selinux --disabled
firewall --service=ssh

bootloader --location=mbr --driveorder=sda --append="crashkernel=auth"

# Disk Partitioning
clearpart --all --initlabel --drives=sda
part /boot --ondisk=sda  --size=1000
part pv.1                --ondisk=sda  --size=1     --grow
volgroup vg_os --pesize=4096 pv.1

logvol /tmp           --vgname=vg_os --size=10000  --name=lv_tmp
logvol /var           --vgname=vg_os --size=100000 --name=lv_var
logvol /var/log/audit --vgname=vg_os --size=5000   --name=lv_var_log_audit
logvol swap           --vgname=vg_os --size=10000  --name=lv_swap
logvol /              --vgname=vg_os --size=100000 --name=lv_root --grow


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
curl http://admin-scripts/ks/sandbox-finish.sh -o /root/sandbox-finish.sh
chmod 0755 /root/sandbox-finish.sh
echo "Finished Post Install: ${timestamp}"
) 2>&1 | /usr/bin/tee /root/install-post.out 2>&1
chvt 1
%end

