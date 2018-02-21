auth --useshadow --passalgo=SHA256 --kickstart
install
###############################  CUSTOM  ##############################################################
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
#######################################################################################################
text
firewall --disabled
firstboot --disable
ignoredisk --only-use=sda,sdb
keyboard --vckeymap=us --xlayouts=''
lang en_US.UTF-8

###############################  CUSTOM  ##############################################################
network  --bootproto=dhcp --hostname=p-hyper-1.p1.sigma.dsci
#######################################################################################################
reboot
rootpw --iscrypted $5$NjDjla2l$uJ1J7ThlPtNR8bdRxa0b8UVOYNZzsf/FcBUPcT2Mig3
selinux --disabled
services --disabled="gpm,sendmail,cups,pcmcia,isdn,rawdevices,hpoj,bluetooth,openibd,avahi-daemon,avahi-dnsconfd,hidd,hplip,pcscd" --enabled="chronyd"
skipx
timezone UTC --isUtc
bootloader --append="nofb quiet splash=quiet crashkernel=auto" --location=mbr --boot-drive=sda
zerombr
clearpart --all --initlabel --disklabel=gpt --drives=sda,sdb
part     biosboot        --fstype="biosboot" --ondisk=sda   --size=1
part     /boot           --fstype="xfs"      --ondisk=sda   --size=1000
part     pv.01           --fstype="lvmpv"    --ondisk=sda   --size=1     --grow
part     pv.02           --fstype="lvmpv"    --ondisk=sdb   --size=1     --grow
volgroup vg_os           --pesize=4096       pv.01
volgroup vg_data         --pesize=4096       pv.02
logvol   /               --fstype="xfs"      --size=150000  --name=lv_root          --vgname=vg_os
logvol   /var            --fstype="xfs"      --size=100000  --name=lv_var           --vgname=vg_os
logvol   /var/log/audit  --fstype="xfs"      --size=10000   --name=lv_var_log_audit --vgname=vg_os
logvol   /data           --fstype="ext4"     --size=50000   --name=lv_data          --vgname=vg_data  --grow

%packages
@Base
@Core
chrony
dhclient
kernel-firmware
kexec-tools
ntp
puppet-agent
redhat-lsb-core
rsync
sudo
wget
yum
ipa-client
libvirt
qemu-kvm
foreman-libvirt
virt-manager
virt-top
virt-viewer
-*firmware
-b43-openfwwf
-efibootmgr
-fcoe*
-iscsi*

%end

%post --nochroot
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
cp -va /etc/resolv.conf /mnt/sysimage/etc/resolv.conf
/usr/bin/chvt 1
) 2>&1 | tee /mnt/sysimage/root/install.postnochroot.log
%end

%post
logger "Starting anaconda postinstall"
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(

curl http://admin-scripts.p1.sigma.dsci/provisioning/scripts/configure_static_networking_with_bonding.sh -o /root/configure_static_networking_with_bonding.sh
chmod 0755 /root/configure_static_networking_with_bonding.sh
/root/configure_static_networking_with_bonding.sh

#update local time
echo "updating system time"
/usr/sbin/ntpdate -sub c-ipa-1.sigma.dsci
/usr/sbin/hwclock --systohc


yum install -y libsss_sudo $freeipa_client


###############################  CUSTOM  ##############################################################
# Update Yum repositories and remove CentOS public defaults
rm -f /etc/yum.repos.d/CentOS*
cat > /etc/yum.repos.d/sigma.repo << EOF
[sigma-centos-7-base]
name=sigma-centos-7-base
baseurl=http://yum.p1.sigma.dsci/sigma-centos-7-base
enabled=1
gpgcheck=0

[sigma-centos-7-updates]
name=sigma-centos-7-updates
baseurl=http://yum.p1.sigma.dsci/sigma-centos-7-updates
enabled=1
gpgcheck=0

[sigma-dockerrepo]
name=sigma-dockerrepo
baseurl=http://yum.p1.sigma.dsci/sigma-dockerrepo
enabled=1
gpgcheck=0

[sigma-epel]
name=sigma-epel
baseurl=http://yum.p1.sigma.dsci/sigma-epel
enabled=1
gpgcheck=0

[sigma-puppetlabs-el7]
name=sigma-puppetlabs-el7
baseurl=http://yum.p1.sigma.dsci/sigma-puppetlabs-el7
enabled=1
gpgcheck=0

[sigma-foreman-1.15]
name=sigma-foreman-1.15
baseurl=http://yum.p1.sigma.dsci/sigma-foreman-1.15
enabled=1
gpgcheck=0

[sigma-foreman-plugins-1.15]
name=sigma-foreman-plugins-1.15
baseurl=http://yum.p1.sigma.dsci/sigma-foreman-plugins-1.15
enabled=1
gpgcheck=0


[sigma-sclo-rh-el7]
name=sigma-sclo-rh-el7
baseurl=http://yum.p1.sigma.dsci/sigma-sclo-rh-el7
enabled=1
gpgcheck=0

[sigma-sclo-sclo-el7]
name=sigma-sclo-sclo-el7
baseurl=http://yum.p1.sigma.dsci/sigma-sclo-sclo-el7
enabled=1
gpgcheck=0

EOF
#######################################################################################################




# update all the base packages from the updates repository
if [ -f /usr/bin/dnf ]; then
  dnf -y update
else
  yum -t -y update
  rm -f /etc/yum.repos.d/CentOS*
fi


if [ -f /usr/bin/dnf ]; then
  dnf -y install puppet-agent
else
  yum -t -y install puppet-agent
fi

cat > /etc/puppetlabs/puppet/puppet.conf << EOF


[main]
vardir = /opt/puppetlabs/puppet/cache
logdir = /var/log/puppetlabs/puppet
rundir = /var/run/puppetlabs
ssldir = /etc/puppetlabs/puppet/ssl
ordering = manifest

[agent]
pluginsync      = true
report          = true
ignoreschedules = true
ca_server       = puppet-ca
certname        = ${fqdn}
environment     = p1
server          = puppet


EOF

puppet_unit=puppet
/usr/bin/systemctl list-unit-files | grep -q puppetagent && puppet_unit=puppetagent
/usr/bin/systemctl enable ${puppet_unit}
/sbin/chkconfig --level 345 puppet on

# export a custom fact called 'is_installer' to allow detection of the installer environment in Puppet modules
export FACTER_is_installer=true
# passing a non-existent tag like "no_such_tag" to the puppet agent only initializes the node
#/opt/puppetlabs/bin/puppet agent --config /etc/puppetlabs/puppet/puppet.conf --onetime --tags no_such_tag --server c-prov-1.sigma.dsci --no-daemonize





mkdir -p /facts

###############################  CUSTOM  ##############################################################
puppet_role=$( echo "p1/hypervisor_server" | sed -e "s/^.*\///" )
puppet_environment="p1"
#######################################################################################################
cat << EOF > /facts/puppet_role.fact
# Puppet Role and Foreman Hostgroup
# DO NOT MOTIFY or you will bring down PLAGUES upon yourself, your family, and your coworkers!
${puppet_role}
EOF

cat > /facts/puppet_environment.fact << EOF
# Puppet fact populated by provisoining user_data.  DO NOT MODIFY!
${puppet_environment}
EOF

) 2>&1 | tee /root/install.post.log
#exit 0

%end

# Configure Libvirt KVM Hypervisor Software
%post
logger "Configuring Libvirt"
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
curl http://admin-scripts.p1.sigma.dsci/provisioning/scripts/finish_libvirt_config.sh -o /root/finish_libvirt_config.sh
chmod 0755 /root/finish_libvirt_config.sh
curl http://kvm.p1.sigma.dsci/sigma-base-server-img.qcow2 -o /data/kvm/images/sigma-base-server-img.qcow2
) 2>&1 | tee /root/install.post-libvirt.log
#exit 0

%end

%post
logger "Configuring Finishing"
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
sync
# Inform the build system that we are done.
#echo "Informing Foreman that we are built"
#wget -q -O /dev/null --no-check-certificate http://c-prov-1.sigma.dsci/unattended/built?token=1e4728f0-3f50-4aa8-819e-17d8d77898a1
) 2>&1 | tee /root/install.post-finish.log
#exit 0

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
