#!/usr/bin/env bash

fqdn=$1
environment=$2
role=$3

if [ "${fqdn}" == "" ]; then
    echo "Oops.  Please supply the FQDN as the first argument to this script."
    exit 1
fi

if [ "${environment}" == "" ]; then
    echo "Oops.  Please supply the ENVIRONMENT (ie: p1) as the second argument to this script."
    exit 1
fi

if [ "${role}" == "" ]; then
    echo "Oops.  Please supply the ROLE (ie: identity_server) as the third argument to this script."
    exit 1
fi

# Configure static network interface
systemctl disable NetworkManager
systemctl stop NetworkManager
primary_interface=$( netstat -rn | grep "^\s*0.0.0.0" | awk '{ print $8 }' )
primary_gateway=$( netstat -rn | grep "^\s*0.0.0.0" | awk '{ print $2 }' )
primary_ip=$( ip addr show | grep inet | grep "${primary_interface}" | awk '{ print $2 }' | awk -F '/' '{ print $1 }' )
primary_netmask=$( ifconfig | grep "inet ${primary_ip}" | awk '{ print $4 }' )

cat << EOF > /etc/hostname
${fqdn}
EOF
hostname ${fqdn}

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-${primary_interface}
DEVICE="${primary_interface}"
TYPE="Ethernet"
BOOTPROTO="static"
ONBOOT=yes
PEERDNS=yes
PEERROUTES=yes
DEFROUTE=yes
IPADDR="${primary_ip}"
NETMASK="${primary_netmask}"
GATEWAY="${primary_gateway}"
EOF

#update local time
echo "updating system time"
/usr/sbin/ntpdate -sub c-ipa-1.sigma.dsci
/usr/sbin/hwclock --systohc

# update all the base packages from the updates repository
yum -t -y update
rm -f /etc/yum.repos.d/CentOS*

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
environment     = ${environment}
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
puppet_role=$( echo "${environment}/${role}" | sed -e "s/^.*\///" )
puppet_environment="${environment}"
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

if [ "${role}" == "identity_server" ]; then
    curl http://admin-scripts.p1.sigma.dsci/provisioning/scripts/ipa_slave_build.sh -o /root/ipa_slave_build.sh
    chmod 0755 /root/ipa_slave_build.sh
    yum install -y git ipa-server ipa-server-dns
elif [ "${role}" == "provisioning_server" ]; then
    domain="p1.sigma.dsci"
    realm="SIGMA.DSCI"
    curl http://admin-scripts.p1.sigma.dsci/provisioning/scripts/foreman_island_init.sh -o /root/foreman_island_init.sh
    curl http://admin-scripts.p1.sigma.dsci/provisioning/scripts/hammer_time.sh -o /root/hammer_time.sh
    chmod 0755 /root/foreman_island_init.sh /root/hammer_time.sh
    yum install -y git foreman-installer jq
fi

exit 0

