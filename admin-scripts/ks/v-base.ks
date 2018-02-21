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
ignoredisk --only-use=vda
keyboard --vckeymap=us --xlayouts=''
lang en_US.UTF-8

network  --bootproto=dhcp
reboot
rootpw --iscrypted $5$NjDjla2l$uJ1J7ThlPtNR8bdRxa0b8UVOYNZzsf/FcBUPcT2Mig3
selinux --disabled
services --disabled="gpm,sendmail,cups,pcmcia,isdn,rawdevices,hpoj,bluetooth,openibd,avahi-daemon,avahi-dnsconfd,hidd,hplip,pcscd" --enabled="chronyd"
skipx
timezone UTC --isUtc
bootloader --append="nofb quiet splash=quiet crashkernel=auto" --location=mbr --boot-drive=vda
zerombr
clearpart --all --initlabel --disklabel=gpt --drives=vda
part     biosboot        --fstype="biosboot" --ondisk=vda   --size=1
part     /boot           --fstype="xfs"      --ondisk=vda   --size=1000
part     pv.01           --fstype="lvmpv"    --ondisk=vda   --size=1     --grow
volgroup vg_os           --pesize=4096       pv.01
logvol   /               --fstype="xfs"      --size=150000  --name=lv_root          --vgname=vg_os
logvol   /var            --fstype="xfs"      --size=100000  --name=lv_var           --vgname=vg_os
logvol   /var/log/audit  --fstype="xfs"      --size=10000   --name=lv_var_log_audit --vgname=vg_os

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
git
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



# Configure static network interface
systemctl disable NetworkManager
systemctl stop NetworkManager
primary_interface=$( netstat -rn | grep "^\s*0.0.0.0" | awk '{ print $8 }' )
primary_gateway=$( netstat -rn | grep "^\s*0.0.0.0" | awk '{ print $2 }' )
primary_ip=$( ip addr show | grep inet | grep "${primary_interface}" | awk '{ print $2 }' | awk -F '/' '{ print $1 }' )
primary_netmask=$( ifconfig | grep "inet ${primary_ip}" | awk '{ print $4 }' )
fqdn=$( hostname -f )

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-${primary_interface}
DEVICE="${primary_interface}"
TYPE="Ethernet"
BOOTPROTO="dhcp"
ONBOOT=yes
PEERDNS=yes
PEERROUTES=yes
DEFROUTE=yes
EOF

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

#puppet_unit=puppet
#/usr/bin/systemctl list-unit-files | grep -q puppetagent && puppet_unit=puppetagent
#/usr/bin/systemctl enable ${puppet_unit}
#/sbin/chkconfig --level 345 puppet on

# export a custom fact called 'is_installer' to allow detection of the installer environment in Puppet modules
export FACTER_is_installer=true
# passing a non-existent tag like "no_such_tag" to the puppet agent only initializes the node
#/opt/puppetlabs/bin/puppet agent --config /etc/puppetlabs/puppet/puppet.conf --onetime --tags no_such_tag --server c-prov-1.sigma.dsci --no-daemonize





mkdir -p /facts

) 2>&1 | tee /root/install.post.log
#exit 0

%end

%post
logger "Configuring Finishing"
exec < /dev/tty3 > /dev/tty3
#changing to VT 3 so that we can see whats going on....
/usr/bin/chvt 3
(
sync
) 2>&1 | tee /root/install.post-finish.log
#exit 0

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
